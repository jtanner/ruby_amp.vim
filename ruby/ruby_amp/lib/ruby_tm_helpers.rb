# TextMate helpers
# Author: Tim Harper with Lead Media Partners.
# http://code.google.com/p/productivity-bundle/

def exit_discard
  exit 200;
end

def exit_replace_text
  exit 201;
end

def exit_replace_document
  exit 202;
end

def exit_insert_text
  exit 203;
end

def exit_insert_snippet
  exit 204;
end

def exit_show_html
  exit 205
end

def exit_show_tool_tip
  exit 206;
end

def exit_create_new_document
  exit 207;
end

def tm_open(file, options = {})
  line = options[:line]
  wait = options[:wait]
  if line.nil? && /^(.+):(\d+)$/.match(file)
    file = $1
    line = $2
  end

  unless /^\//.match(file)
    file = File.join((ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd), file)
  end

  args = []
  args << "-w" if wait
  args << e_sh(file)
  args << "-l #{line}" if line
  %x{"#{ENV['TM_SUPPORT_PATH']}/bin/mate" #{args * " "}}
end

# escape text to make it useable in a shell script as one “word” (string)
def e_sh(str)
  str.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/n, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
end

def pbcopy(contents)
  exit if fork            # Parent exits, child continues.
  Process.setsid          # Become session leader.
  exit if fork            # Zap session leader.

  # After this point you are in a daemon process
  pid = fork do
    STDOUT.reopen(open('/dev/null'))
    STDERR.reopen(open('/dev/null'))
    sleep 0.05
    IO.popen('pbcopy', 'w') { |pb| pb << contents }
    exit
  end
  Process.detach(pid)
end

# this method only applies when the whole document contents are sent in
def tm_expanded_selection(options = {})
  text=ENV['TM_SELECTED_TEXT'].to_s
  return text unless text.empty?

  options = {
    :input_type => :line,
    :input => nil,
    :forward => /\w*/i,
    :backward => /\w*/i,
    :line_number => ENV['TM_LINE_NUMBER'].to_i,
    :col_number => ENV['TM_COLUMN_NUMBER'].to_i
  }.merge(options)

  col_number, line_number = options[:col_number], options[:line_number]

  doc = options[:input] ||= $stdin.read

  line =
    case options[:input_type]
    when :doc  then doc.split("\n")[line_number - 1].to_s
    when :line then doc.rstrip
    else
      raise "Can't handle input_type #{options[:input_type]} for tm_expanded_selection"
    end

  last_part = line[ (col_number - 1)..-1]
  first_part = col_number == 1 ? "" : line[ 0..col_number - 2]

  last_part.gsub!(/^(#{options[:forward]}){0,1}.*$/i) { $1 }

  first_part.reverse!
  first_part.gsub!(/^(#{options[:backward]}){0,1}.*$/i) { $1 }
  first_part.reverse!
  first_part + last_part
end



module Enumerable
  # TODO remove when 1.9 supports natively
  def map_with_index
    result = []
    each_with_index do |item, idx|
      result << yield(item, idx)
    end
    result
  end
end
