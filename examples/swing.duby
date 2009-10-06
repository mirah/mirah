import javax.swing.JFrame
import javax.swing.JButton
import java.awt.event.ActionListener

frame = JFrame.new "Welcome to Duby"
frame.setSize 300, 300
frame.setVisible true

button = JButton.new "Press me"
frame.add button
frame.show
