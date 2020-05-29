#!/usr/bin/env ruby

require 'open3'
require 'curses'

JQQ_VERSION = "0.0.1"

FILE_Y = 0
EXPR_Y = 1
OUTPUT_Y = 2

CSI_UP = 'A'
CSI_DOWN = 'B'
CSI_RIGHT = 'C'
CSI_LEFT = 'D'

KEY_BACKSPACE = 127
KEY_CTRL_A = 1
KEY_CTRL_D = 4
KEY_CTRL_E = 5
KEY_CTRL_K = 11
KEY_CTRL_U = 21
KEY_ENTER = 10
KEY_ESCAPE = 27
KEY_LEFT_BRACKET = '['
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

def print_expr(expr_win, expr, expr_pos)
  expr_win.clear
  expr_win.addstr(expr)
  expr_win.setpos(0, expr_pos)
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

  expr_pos = expr.size

  print_title(title_win, file)
  print_expr(expr_win, expr, expr_pos)
  print_output(output_win, expr, file, :max_lines=>Curses.lines)
  expr_win.refresh

  escape_mode = false
  csi_mode = false # control sequence introducer

  running = true
  while running do
    should_render = false
    should_echo = false

    begin
      key = expr_win.getch

      if escape_mode
        if csi_mode
          case key
          when CSI_UP
            # TODO
          when CSI_DOWN
            # TODO
          when CSI_LEFT
            expr_pos = [0, expr_pos - 1].max
            should_echo = true
          when CSI_RIGHT
            expr_pos = [expr.size, expr_pos + 1].min
            should_echo = true
          end

          csi_mode = false
          escape_mode = false
        else # if not csi_mode
          if key == KEY_LEFT_BRACKET
            csi_mode = true
          elsif key == 'b'
            # alt-left
            escape_mode = false
          elsif key == 'f'
            # alt-right
            escape_mode = false
          elsif key == 127
            # alt-backspace
            escape_mode = false
          else
            escape_mode = false
          end
        end
      else
        case key
        when KEY_BACKSPACE
          if expr_pos > 0
            # remove character at expr_pos, effectively
            expr = expr[0...(expr_pos - 1)] + expr[expr_pos..-1]
            expr_pos -= 1
            should_echo = true
          end
        when KEY_CTRL_A
          expr_pos = 0
          should_echo = true
        when KEY_CTRL_D
          running = false
        when KEY_CTRL_E
          expr_pos = expr.size
          should_echo = true
        when KEY_CTRL_K
          expr = expr[0...expr_pos]
          expr_pos = expr.size
          should_echo = true
        when KEY_CTRL_U
          expr = ""
          expr_pos = 0
          should_echo = true
        when KEY_ENTER
          should_render = true
        when KEY_ESCAPE
          escape_mode = true
        when KEY_WINDOW_RESIZE
          should_render = true
        else
          # add character at expr_pos
          expr = expr[0...expr_pos] + key.chr + expr[expr_pos..-1]
          expr_pos += 1
          should_echo = true
        end
      end

      if should_render
        print_expr(expr_win, expr, expr_pos)
        print_output(output_win, expr, file, :max_lines=>Curses.lines)
        expr_win.refresh
      elsif should_echo
        print_expr(expr_win, expr, expr_pos)
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
