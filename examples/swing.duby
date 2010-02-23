import javax.swing.JFrame
import javax.swing.JButton

# FIXME blocks need to be inside a MethodDefinition, but main doesn't
# have one.
def self.run
  frame = JFrame.new "Welcome to Duby"
  frame.setSize 300, 300
  frame.setVisible true

  button = JButton.new "Press me"
  frame.add button
  frame.show

  button.addActionListener do |event|
    JButton(event.getSource).setText "Duby Rocks!"
  end
end

run