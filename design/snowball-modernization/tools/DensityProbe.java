import javax.microedition.lcdui.*;
import javax.microedition.lcdui.game.Sprite;
public class DensityProbe {
 static void check(boolean value,String message){if(!value)throw new RuntimeException(message);}
 static void green(Image image)throws Exception{
  int[] pixels=new int[image.getWidth()*image.getHeight()];image.getRGB(pixels,0,image.getWidth(),0,0,image.getWidth(),image.getHeight());
  for(int pixel:pixels)check(pixel==0xff00ff00,"Cropped RGB changed: "+Integer.toHexString(pixel));
 }
 public static void main(String[] args)throws Exception{
  Image title=Image.createImage("/cover7650r.png");check(title.getWidth()==176 && title.getHeight()==166,"Logical title dimensions changed");
  Image idle=Image.createImage("/sarahstand2.png");check(idle.getWidth()==76 && idle.getHeight()==25,"Logical sprite dimensions changed");
  Image source=Image.createImage(4,4);check(source.getWidth()==4 && source.getHeight()==4,"Mutable logical dimensions changed");
  Graphics g=source.getGraphics();g.setColor(0xff0000);g.fillRect(0,0,2,4);g.setColor(0x00ff00);g.fillRect(2,0,2,4);
  Image region=Image.createImage(source,2,0,2,4,Sprite.TRANS_NONE);green(region);
  Image rotated=Image.createImage(source,2,0,2,4,Sprite.TRANS_ROT90);check(rotated.getWidth()==4 && rotated.getHeight()==2,"Rotated region dimensions changed");green(rotated);
  int[] block={0xff00ff00,0xff00ff00,0xff00ff00,0xff00ff00};Image rgb=Image.createRGBImage(block,2,2,true);green(rgb);
  System.out.println("PASS: logical asset dimensions, mutable image sizes, high-density getRGB, scaled region crops, rotation and drawRGB");System.exit(0);
 }
}
