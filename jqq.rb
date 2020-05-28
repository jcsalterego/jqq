#!/usr/bin/env ruby

require 'open3'
require 'curses'

JQQ_VERSION = "0.0.1"

FILE_Y = 0
EXPR_Y = 1
OUTPUT_Y = 2

def draw_input(win, expr)
  win.setpos(EXPR_Y, 0)
  win.clrtoeol
  win.addstr(expr)
end

def jq(*args)
  params = ["jq"] + args
  stdout, stderr, status = Open3.capture3(*params)

  {
    :stdout => stdout,
    :stderr => stderr,
    :status => status,
  }
end

def print_title(title_win, file)
  title_win.clear
  title_win.addstr("jqq: #{file}")
  title_win.refresh
end

def print_expr(expr_win, expr)
  expr_win.clear
  expr_win.addstr(expr)
  expr_win.refresh
end

def print_output(output_win, expr, file)
  results = jq(expr, file)
  output_win.clear
  output_win.setpos(0, 0)
  if results[:status].exitstatus == 0
    output_win.addstr(results[:stdout])
  else
    output_win.addstr(results[:stderr])
  end
  output_win.refresh
end

def curses_main(argv)
  expr = argv[0]
  file = argv[1]

  Curses.noecho

  expr_win = Curses::Window.new(
    1, # height
    Curses.cols, # width
    1, # top
    0  # left
  )
  title_win = Curses::Window.new(
    1, # height
    Curses.cols, # width
    0, # top
    0  # left
  )
  output_win = Curses::Window.new(
    Curses.lines - 2,
    Curses.cols,
    2,
    0
  )

  print_title(title_win, file)
  print_expr(expr_win, expr)
  print_output(output_win, expr, file)
  expr_win.refresh

  running = true
  while running do
    reeval = false
    begin
      key = expr_win.getch

      case key
      when 127 # backspace
        expr = expr[0..-2]
        print_expr(expr_win, expr)
      when 4 # ^D
        running = false
      when 21 # ^U
        expr = ""
        print_expr(expr_win, expr)
        expr_win.refresh
      when 10 # enter
        print_title(title_win, file)
        print_expr(expr_win, expr)
        print_output(output_win, expr, file)
        expr_win.refresh
      else
        expr += key.chr
        print_expr(expr_win, expr)
      end
    rescue Interrupt => e
      break
    end
  end

  {
    :expr => expr,
    :file => file,
  }
end

def usage
  $stderr.puts "Usage: jqq <expr> <file>"
end

def print_version
  $stderr.puts "jqq Version #{JQQ_VERSION}"
end

def missing_jq?
  `which jq`.strip.empty?
end

def print_needs_jq
  $stderr.puts 'jq not found in $PATH'
end

def preflight_check(argv)
  show_usage = false
  show_version = false
  show_needs_jq = false

  if argv.include?('--version')
    show_version = true
  elsif argv.size < 2
    show_usage = true
  elsif missing_jq?
    show_needs_jq = true
    show_usage = true
  else
    filename = argv[-1]
    unless File.exist?(filename) && !File.directory?(filename)
      show_usage = true
    end
  end

  if show_needs_jq
    print_needs_jq
    exit 1
  elsif show_version
    print_version
    exit 0
  elsif show_usage
    usage
    exit 1
  end
end

def main(argv)
  preflight_check(argv)

  Curses.init_screen
  begin
    state = curses_main(argv)
  ensure
    Curses.close_screen
  end

  puts "jqq #{state[:expr]} #{state[:file]}"
end

if __FILE__ == $0
  main(ARGV)
end