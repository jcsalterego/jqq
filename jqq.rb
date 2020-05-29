#!/usr/bin/env ruby

require 'open3'
require 'curses'

JQQ_VERSION = "0.0.1"

FILE_Y = 0
EXPR_Y = 1
OUTPUT_Y = 2

KEY_BACKSPACE = 127
KEY_CTRL_D = 4
KEY_CTRL_U = 21
KEY_ENTER = 10
KEY_WINDOW_RESIZE = 410

def jq(args, opts={})
  cmds = [
    ["jq"] + args,
    ["head", "-n", opts[:max_lines].to_s],
  ]

  io_read, io_write = IO.pipe
  statuses = Open3.pipeline(*cmds,
    :in=>io_read, :out=>io_write, :err=>io_write)
  io_write.close
  output = io_read.read
  exitstatus = statuses[0].exitstatus

  {
    :output => output,
    :exitstatus => exitstatus,
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

def print_output(output_win, expr, file, opts={})
  results = jq([expr, file], :max_lines=>opts[:max_lines])
  output_win.clear
  output_win.setpos(0, 0)
  output_win.addstr(results[:output])
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
  print_output(output_win, expr, file, :max_lines=>Curses.lines)
  expr_win.refresh

  running = true
  while running do
    render = false
    begin
      key = expr_win.getch

      case key
      when KEY_BACKSPACE
        expr = expr[0..-2]
        print_expr(expr_win, expr)
      when KEY_CTRL_D
        running = false
      when KEY_CTRL_U
        expr = ""
        print_expr(expr_win, expr)
        expr_win.refresh
      when KEY_ENTER
        render = true
      when KEY_WINDOW_RESIZE
        render = true
      else
        expr += key.chr
        print_expr(expr_win, expr)
      end

      if render
        print_title(title_win, file)
        print_expr(expr_win, expr)
        print_output(output_win, expr, file, :max_lines=>Curses.lines)
        expr_win.refresh
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

def print_helpful_command(expr, file)
  if /[ \[\]]/.match(expr)
    full_expr = "'%s'" % [expr]
  else
    full_expr = expr
  end

  puts "jqq #{full_expr} #{file}"
end

def main(argv)
  preflight_check(argv)

  Curses.init_screen
  begin
    state = curses_main(argv)
  ensure
    Curses.close_screen
  end

  print_helpful_command(state[:expr], state[:file])
end

if __FILE__ == $0
  main(ARGV)
end
