#! /bin/ruby -W0
require 'cast'

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

	def self.execute(command)
		io = IO.popen(command)
		i = 0
		result = ""
		while (ret = io.read(1000)) != nil
			result += ret
		end
		io.close
		return result
	end

	def self.isCharacterNumeric?(lookAhead)
		return (lookAhead =~ /[0-9]/) != nil
	end

	def self.isCharacterAlpha?(lookAhead)
		return (lookAhead =~ /[A-Za-z]/) != nil
	end

	def self.isNumeric?(string)
		string.each_char() do |c|
			if Std::isCharacterNumeric?(c) == false
				return false
			end
		end
		return true
	end

	def self.isAlpha?(string)
		string.each_char() do |c|
			if Std::isCharacterAlpha?(c) == false
				return false
			end
		end
		return true
	end

	def self.setStringToAlphaNumeric(string)
		str = ""
		string.each_char() do |c|
			if Std::isCharacterAlpha?(c) == false && Std::isCharacterNumeric?(c) == false
				next
			end
			str += c
		end
		return str
	end

	def self.gccmethodsLines(filename)
		result = []
		content = Std::file_get_content(filename).split("\n")
		un = Std::execute('ctags -x ' + filename + ' 2>&-')
		de = Std::execute('ctags -x ' + filename + ' 2>&1')
		puts filename
		de = de.gsub("Second entry ignored", "").gsub("Duplicate entry in file", "Method").strip!
		puts de
		de.split("\n").each do |l|
			l.split(" ").each do |w|
				if Std::isNumeric?(Std::setStringToAlphaNumeric(w)) == false
					next
				end
				infos = {"start" => 0, "end" => 0, "name" => "unknow", "content" => []}
				infos["start"] = Std::setStringToAlphaNumeric(w).to_i
				if l.include?("line") == true
					infos["start"] -= 1
				end
				infos["start"] -= 1

				if content[infos["start"]].include?("::") == true
					split = content[infos["start"]].split("(")[0].split("::")
					infos["name"] = split[split.length - 1]
				end

				accolad = 0
				wait = true
				(infos["start"]...content.length).each() do |lineid|
					infos["content"].push(content[lineid])
					if content[lineid].include?("{") == true
						accolad += 1
						wait = false
					end
					if content[lineid].include?("}") == true
						accolad -= 1
						if accolad == 0 && wait == false
							infos["end"] = lineid
							break
						end
					end
				end
				result.push(infos)
				break
			end
		end
		return result.sort_by { |k| k["start"] }
	end
end

class FileToHtml

	TEMPLATE_PATH = "/templates/file.html"

	def initialize(project_name, author, file_path, file_name)
		@project_name = project_name
		@author = author
		@file_path = file_path
		@file = Std::file_get_content(file_path)
		@file_time = File.atime(file_path).to_s[0...20]
		@file_size = self.get_file_size(file_path)
		@file_name = file_name
		@template = Std::file_get_content(File.join(__dir__, FileToHtml::TEMPLATE_PATH))
		puts @template
		@html = self.generate_html_file()
	end

	def get_file_size(file_path)
		bytes = File.stat(file_path).size
		bytes = (bytes / (1024.0)).round(2)
		return bytes.to_s + " KB"
	end

	def generate_methods_code()
		code = ""
		Std::gccmethodsLines(@file_path).each do |obj|
			method = "<div class=\"file\">"
			method += "<div class=\"file-header\">"
			method += "<div class=\"file-info\">"
			method += obj["content"].length.to_s
			method += " lines"
			method += "<span class=\"file-info-divider\"></span>"
			method += obj["name"]
			method += "</div>"
			method += "</div>"
			method += "<div itemprop=\"text\" class=\"blob-wrapper data type-java\">"
			method += "<table class=\"highlight tab-size js-file-line-container\" data-tab-size=\"8\">"
			method += "<tbody>"
			obj["content"].each do |line|
				method += generate_line_code(line)
			end
			method += "</tbody>"
			method += "</table>"
			method += "</div>"
			method += "</div>"
			code += method
		end
		return code
	end

	def generate_line_code(line)
		i = 0
		code = ""
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
		return code
	end

	def get_number_of_lines()
		return @file.split("\n").length.to_i
	end

	def generate_html_file()
		html_file = @template
		code = self.generate_methods_code()
		html_file = html_file.gsub("@filecontent", code)
		html_file = html_file.gsub("@numberoflines", get_number_of_lines().to_s)
		html_file = html_file.gsub("@author", @author)
		html_file = html_file.gsub("@filename", @file_name)
		html_file = html_file.gsub("@file_datetime", @file_time)
		html_file = html_file.gsub("@pods", @file_size)
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
			"name" => {"active" => false, "args" => 1},
			"author" => {"active" => false, "args" => 1},
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
	puts "	-r [path]       \"Recursive mode\""
	puts "flags:"
	puts "	--name [name]   \"project name\""
	puts "	--author [name] \"author name\""
	puts "	--c             \"c code\""
	puts "	--cpp           \"cpp code\""
	puts "	--file [path]   \"doc one file\""
	puts "	--help          \"print help\""
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
	project_name = "Project"
	if params.flags["name"]["active"]
		project_name = params.flags["name"]["arg0"]
	end
	author = "unknow"
	if params.flags["author"]["active"]
		author = params.flags["author"]["arg0"]
	end
	directory_name = "site"
	if params.flags["name"]["active"]
		directory_name = params.flags["name"]["arg0"]
	end
	Dir.mkdir(directory_name) unless File.exists?(directory_name)

	files[0].each do |filepath|
		#puts FileToHtml.new("AbstractVM", "jguyet", file)
		path = File.absolute_path(filepath.to_s).gsub(File.absolute_path(argpath), "")
		llast = File.absolute_path(directory_name)
		path = path[1...path.length]
		## create dirs
		path.split("/").each do |dir|
			if path.split("/")[path.split("/").length - 1] == dir
				break
			end
			puts "HHHHH => " + llast
			llast = File.join(llast, dir)
			if File.exist?(llast) == false
				Dir.mkdir(llast) unless File.exists?(llast)
			end
		end
		filename = File.join(File.absolute_path(directory_name), File.dirname(path), File.basename(filepath.to_s, ".*"))
		pagehtmlcode = FileToHtml.new(project_name, author, filepath.to_s, File.basename(filepath.to_s))
		Std::file_put_content(filename + ".html", pagehtmlcode.to_s)
		puts "----------"
		puts "PATH     : " + path
		puts "PATH TO  : " + filename + ".html"
		puts "basename : " + File.basename(filepath.to_s)
	end
	#puts FileToHtml.new("AbstractVM", "jguyet", file)
end

___MAIN(ARGV)
