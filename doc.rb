#! /bin/ruby -W0

class Std
	def self.file_get_content(file_name)
		if File.exist?(file_name) == false
			return ""
		end
		file = File.open(file_name, "r")
		data = file.read
		file.close
		return data
	end

	def self.file_put_content(file_name, content)
		file = nil;
		if File.exist?(file_name) == false
			file = File.new(file_name, "w");
		else
			file = File.open(file_name, "w");
		end
		file.puts(content);
		file.close;
	end
end

class FileToHtml

	TEMPLATE_PATH = "./templates/file.html"

	def initialize(project_name, author, file_path)
		@project_name = project_name
		@author = author
		@file = Std::file_get_content(file_path)
		@template = Std::file_get_content(FileToHtml::TEMPLATE_PATH)
		@html = self.generate_html_file()
	end

	def generate_div_code()
		i = 0
		code = ""
		@file.split("\n").each do |line|
			if line[0] == "/" && line[1] == "/"
				line = "<span class=\"pl-c\">" + line + "</span>"
			end
			["include", "void", "return", "operator", "const"].each do |t|
				line = line.gsub(t, "<span class=\"pl-k\">" + t.to_s + "</span>")
			end
			code += "<tr>\n"
			code += "<td id=\"L" + i.to_s + "\" class=\"blob-num js-line-number\" data-line-number=\"" + i.to_s + "\"></td>"
			code += "<td id=\"LC" + i.to_s + "\" class=\"blob-code blob-code-inner js-file-line\">" + line.to_s + "</td>"
			code += "</tr>\n"
			i += 1
		end
		return code
	end

	def get_number_of_lines()
		return @file.split("\n").length.to_i
	end

	def generate_html_file()
		html_file = @template
		code = self.generate_div_code()
		html_file = html_file.gsub("@filecontent", code)
		html_file = html_file.gsub("@numberoflines", get_number_of_lines().to_s)
		html_file = html_file.gsub("@author", @author)
		html_file = html_file.gsub("@project_name", @project_name)
		return html_file
	end

	def to_s
		return @html
	end
end

class Params
	attr_reader :flags, :params, :extensions

	def initialize(argv)
		@flags_defaults = {
			"path" => {"actived" => true, "name" => "path", "argpos" => {"sens" => false, "pos" => -1}}
		}
		@flags = {
			"help" => {"active" => false, "args" => 0},
			"file" => {"active" => false, "args" => 1},
			"cpp" => {"active" => false, "args" => 0, "exc" => true},
			"c" => {"active" => false, "args" => 0, "exc" => true},
			"path" => {"active" => true, "args" => 1, "pos" => "length[-1]"}
		}
		@params = {
			"r" => {"active" => false, "args" => 1, "arg0" => nil}
		}
		@extensions = {}
		self.load(argv)
		self.load_extension()
	end

	def load(argv)
		last_flag = nil
		@flags_defaults.each do |k, f|
			if f["actived"] == true
				if f["argpos"]["sens"] == false
					@flags[f["name"]]["arg0"] = argv[argv.length + f["argpos"]["pos"]]
				else
					@flags[f["name"]]["arg0"] = argv[f["argpos"]["pos"]]
				end
			end
		end
		argv.each do |arg|
			if arg.include?("--") && @flags[arg.gsub("--", "")] != nil && last_flag == nil
				@flags[arg.gsub("--", "")]["active"] = true
				if @flags[arg.gsub("--", "")]["args"] > 0
					last_flag = {"type" => "flags", "name" => arg.gsub("--", ""), "arg" => 0}
				end
			elsif arg.include?("-") && last_flag == nil
				arg.gsub("-", "").each_char do |c|
					if @params[c.to_s] != nil
						@params[c.to_s]["active"] = true
						if @params[c.to_s]["args"] > 0
							last_flag = {"type" => "actions", "name" => c.to_s, "arg" => 0}
						end
					end
				end
			elsif last_flag != nil && last_flag["type"] == "flags"
				@flags[last_flag["name"]]["arg" + last_flag["arg"].to_s] = arg
				last_flag["arg"] = last_flag["arg"].to_i + 1
				if last_flag["arg"].to_i >= @flags[last_flag["name"]]["args"].to_i
					last_flag = nil
				end
			elsif last_flag != nil && last_flag["type"] == "actions"
				@params[last_flag["name"]]["arg" + last_flag["arg"].to_s] = arg
				last_flag["arg"] = last_flag["arg"].to_i + 1
				if last_flag["arg"].to_i >= @params[last_flag["name"]]["args"].to_i
					last_flag = nil
				end
			end
		end
	end

	def load_extension()
		@flags.each do |k, v|
			if v["exc"] == true && v["active"] == true
				@extensions[k.to_s] = true
			end
		end
	end

	def is_correct()
		[@flags, @params].each do |lst|
			lst.each do |k, f|
				if f["active"] == false
					next
				end
				(0..(f["args"].to_i - 1)).each do |i|
					if f["arg" + i.to_s] == nil
						return false
					end
				end
			end
		end
		return true
	end
end

def help()
	puts "--- doc generator"
	puts "--- author: jguyet"
	puts "params:"
	puts "	-r [path]     \"Recursive mode\""
	puts "flags:"
	puts "	--c           \"c code\""
	puts "	--cpp         \"cpp code\""
	puts "	--file [path] \"doc one file\""
	puts "	--help        \"print help\""
end

def get_files_types(path, types, r)
	lst = []
	if File.exist?(path) == false
		return nil
	end
	if File.directory?(path) == false
		types.each do |t|
			if (File.extname(path) == t)
				lst.push(path)
				break
			end
		end
	elsif r == true
		Dir.entries(path).each do |f|
			if f == "." || f == ".." || f[0] == "."
				next
			end
			if File.directory?(File.join(path, f))
				l = get_files_types(File.join(path, f), types, r)
				if l != nil && l.length > 0
					l.each do |n|
						lst.push(n)
					end
				end
			else
				types.each do |t|
					if (File.extname(f) == t)
						lst.push(File.join(path, f))
						break
					end
				end
			end
		end
	end
	return lst
end

def ___MAIN(argv)
	params = Params.new(argv)

	if params.flags["help"]["active"] == true || params.is_correct() == false
		help()
		return
	end
	files = []
	if params.params["r"]["active"] == true
		argpath = params.params["r"]["arg0"]
	elsif params.flags["path"]["arg0"] != nil
		argpath = params.flags["path"]["arg0"]
	else
		help()
		return
	end
	if params.flags["c"]["active"] == true
		files.push(get_files_types(argpath, [".c"], params.params["r"]["active"]))
	end
	if params.flags["cpp"]["active"] == true
		files.push(get_files_types(argpath, [".cpp"], params.params["r"]["active"]))
	end

	directory_name = "./site"
	Dir.mkdir(directory_name) unless File.exists?(directory_name)

	puts File.absolute_path(directory_name)
	puts File.absolute_path(__dir__)
	files[0].each do |filepath|
		#puts FileToHtml.new("AbstractVM", "jguyet", file)
		path = File.absolute_path(filepath.to_s).gsub(File.absolute_path(__dir__), "")
		path = path[1...path.length]
		## create dirs
		llast = File.absolute_path(directory_name)
		path.split("/").each do |dir|
			if path.split("/")[path.split("/").length - 1] == dir
				break
			end
			llast = File.join(llast, dir)
			if File.exist?(llast) == false
				Dir.mkdir(llast) unless File.exists?(llast)
			end
		end
		filename = File.join(File.absolute_path(directory_name), File.dirname(path), File.basename(filepath.to_s, ".*"))
		pagehtmlcode = FileToHtml.new("AbstractVM", "jguyet", filepath.to_s)
		Std::file_put_content(filename + ".html", pagehtmlcode.to_s)
		puts "----------"
		puts "PATH     : " + path
		puts "PATH TO  : " + filename + ".html"
		puts "basename : " + File.basename(filepath.to_s)
	end
	#puts FileToHtml.new("AbstractVM", "jguyet", file)
end

___MAIN(ARGV)
