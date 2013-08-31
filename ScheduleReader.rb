#! /usr/bin/env ruby

@departure_times = {}
@arrival_times = {}

@routes = {}

class String
    def strip_prefix(prefix)
        if self.start_with? prefix then
            return self[prefix.length..-1]
        else
            return self
        end
    end
    def indent_after_newline(indent_string = "  ")
        self.split("\n").join("\n#{indent_string}")
    end
end

def jsonify_strings(value)
    if value.is_a? Hash or value.is_a? Array then
        "#{value}"
    else
        value = value.to_s
        if value[0] == '"' and value [-1] == '"' then
            "#{value}"
        else
            "\"#{value}\""
        end
    end
end

class Array
    def to_s()
        string = (self.map do |value|
            jsonify_strings value
        end).join ",\n"
        result = "{\n#{string}".indent_after_newline
        result += "\n}"
    end
end

class Hash
    def to_s()
        string = (self.map do |key, value|
            "#{jsonify_strings key} : #{jsonify_strings value}"
        end).join ",\n"
        result = "{\n#{string}".indent_after_newline
        result += "\n}"
    end
end

@current_route = ""
@current_days = ""
@stops = []

def record_route(departure_time, arrival_time, from, to)
    from ||= ""
    to ||= ""
    @routes[@current_route] ||= {}
    @routes[@current_route][from] ||= {}
    @routes[@current_route][from][:departures] ||= []
    @routes[@current_route][from][:departures] << {:to => to, :time => departure_time, :days => @current_days}
    @routes[@current_route][to] ||= {}
    @routes[@current_route][to][:arrivals] ||= []
    @routes[@current_route][to][:arrivals] << {:from => from, :time => arrival_time, :days => @current_days}
    @routes
end

def record(dictionary, time, from, to)
    from ||= ""
    to ||= ""
    dictionary[from] ||= {}
    dictionary[from][to] ||= []
    dictionary[from][to] << {:time => time, :route => "#{@current_route}", :days => "#{@current_days}"}
    dictionary
end

def extract_times(string)
    def contains_special_stop?(time)
        time.include? "-"
    end
    def special_stop(time)
        parts = time.split("-", 2)
        if parts.length == 2 then
            return {:time => parts[1].strip, :stop => parts[0].strip}
        else
            return nil
        end
    end
    times = string.split(">")
    current_stops_index = 0
    previous_stop = nil
    previous_time = nil
    times.each do |command|
        command = command.strip
        if command != "" then
            time = ""
            stop = ""
            if contains_special_stop? command then
                parts = special_stop command
                time = parts[:time]
                stop = parts[:stop]
            else
                time = command
                stop = @stops[current_stops_index]
                current_stops_index += 1
            end
            if previous_stop != nil and previous_time != nil then
                # record the times and stops in the routes dictionary
                record_route(previous_time, time, previous_stop, stop)
                # record the times and stops in the departure/arrival dictionaries
                record(@departure_times, previous_time, previous_stop, stop)
                record(@arrival_times, time, previous_stop, stop)
            end
            previous_time = time
            previous_stop = stop
        else
            current_stops_index += 1
        end
        if current_stops_index == @stops.length then
            current_stops_index = 0
        end
    end
end

def figure_out_route(string)
    stops = string.split ">"
    @stops = []
    stops.each { |stop|
        @stops << stop.strip
    }
end

def print_data()
    data_dict = {
        :route_based => @routes,
        :time_based => {
            :departures => @departure_times,
            :arrivals => @arrival_times
        }
    }
    puts "#{data_dict}"
end

def parse_input_for_commands(commands_dict, input, &default)
    command_found = false
    commands_dict.each do |command, block|
        if input.start_with? command then
            line = input.strip_prefix(command).strip
            block.call line
            command_found = true
            break
        end
    end
    default.call(input) if not command_found and block_given?
end

@set_commands = {
    "route" => Proc.new do |line|
        parts = line.split(":", 2)
        if (parts.length == 1) then
            @current_route = parts[0].strip
        elsif
            @current_route = parts[0].strip
            figure_out_route(parts[1].strip)
        end
    end,
    "days" => Proc.new do |line|
        @current_days = line
    end,
    "stops" => Proc.new do |line|
        figure_out_route(line)
    end
}

@commands = {
    ":set" => Proc.new do |line|
        parse_input_for_commands @set_commands, line
    end,
    ":q" => Proc.new do |line|
        print_data()
        exit
    end,
    "#" => Proc.new do |line|
        # '#' represents a comment and the line is ignored
    end
}

while true do
    parse_input_for_commands @commands, gets do |line|
        extract_times line
    end
end
