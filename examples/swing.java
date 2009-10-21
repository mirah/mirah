// Generated from examples/swing.duby
package examples;
public class swing extends java.lang.Object {
  public static void main(java.lang.String[] argv) {
    javax.swing.JFrame frame = new javax.swing.JFrame("Welcome to Duby");
    frame.setSize(300, 300);
    frame.setVisible(true);
    javax.swing.JButton button = new javax.swing.JButton("Press me");
    frame.add(button);
    frame.show();
    button.addActionListener(new AL());
  }
}
