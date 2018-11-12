module Diff
  Line = Struct.new(:number, :text)

  def self.lines(document)
    document = document.lines if document.is_a?(String)
    document.map.with_index { |text, i| Line.new(i + 1, text) }
  end

  def self.diff(a, b, differ: Myers)
    differ.diff(lines(a), lines(b))
  end
end

class Myers
  def self.diff(a, b)
    new(a, b).diff
  end

  def initialize(a, b)
    @a, @b = a, b
  end

  def shortest_edit
    n, m = @a.size, @b.size
    max = n + m

    v = Array.new(2 * max + 1)
    v[1] = 0
    trace = []

    (0..max).step do |d|
      trace << v.clone

      (-d..d).step(2) do |k|

        if k == -d or (k != d and v[k - 1] < v[k + 1])
          x = v[k + 1]
        else
          x = v[k - 1] + 1
        end

        y = x - k

        # NOTE 比较相等环节
        while x < n and y < m and @a[x].text == @b[y].text
          x, y = x + 1, y + 1
        end

        v[k] = x

        return trace if x >= n and y >= m
      end
    end
  end

  def backtrack
    x, y = @a.size, @b.size

    shortest_edit.each_with_index.reverse_each do |v, d|
      k = x - y

      # 判断 x 的大小
      if k == -d or (k != d and v[k - 1] < v[k + 1])
        prev_k = k + 1
      else
        prev_k = k - 1
      end

      prev_x = v[prev_k]
      prev_y = prev_x - prev_k

      while x > prev_x and y > prev_y
        yield x - 1, y - 1, x, y
        x, y = x - 1, y - 1
      end

      # 如果d=0 就
      yield prev_x, prev_y, x, y if d > 0

      x, y = prev_x, prev_y
    end
  end

  def diff
    diff = []

    backtrack do |prev_x, prev_y, x, y|
      a_line, b_line = @a[prev_x], @b[prev_y]

      if x == prev_x
        diff.unshift(Diff::Edit.new(:ins, nil, b_line))
      elsif y == prev_y
        diff.unshift(Diff::Edit.new(:del, a_line, nil))
      else
        diff.unshift(Diff::Edit.new(:eql, a_line, b_line))
      end
    end

    diff
  end

end

module Diff
  Edit = Struct.new(:type, :old_line, :new_line) do
    def old_number
      old_line ? old_line.number.to_s : ""
    end

    def new_number
      new_line ? new_line.number.to_s : ""
    end

    def text
      (old_line || new_line).text
    end
  end
end

module Diff
  class Printer

    TAGS = {eql: ' ', del: '-', ins: '+'}

    COLORS = {
      del:     "\e[31m",
      ins:     "\e[32m",
      default: "\e[39m"
    }

    LINE_WIDTH = 4

    def initialize(output: $stdout)
      @output = output
      @colors = output.isatty ? COLORS : {}
    end

    def print(diff)
      diff.each { |edit| print_edit(edit) }
    end

    def print_edit(edit)
      col   = @colors.fetch(edit.type, "")
      reset = @colors.fetch(:default, "")
      tag   = TAGS[edit.type]

      old_line = edit.old_number.rjust(LINE_WIDTH, ' ')
      new_line = edit.new_number.rjust(LINE_WIDTH, ' ')
      text     = edit.text.rstrip

      @output.puts "#{col}#{tag} #{old_line} #{new_line}  #{text}#{reset}"
    end

  end
end


doc1 = <<EOF
A
B
C
A
B
B
A
EOF

doc2 = <<EOF
C
B
A
B
A
C
EOF

Diff::Printer.new.print Diff.diff(doc1, doc2)
