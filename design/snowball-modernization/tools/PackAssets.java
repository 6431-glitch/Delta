import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.nio.file.*;
import java.util.zip.*;

/** Mechanical atlas packing only; illustrations are produced by Image Gen. */
public class PackAssets {
 static BufferedImage read(String p) throws Exception {return ImageIO.read(Paths.get(p).toFile());}
 static void save(BufferedImage image,Path p)throws Exception{ImageIO.write(image,"png",p.toFile());}
 static BufferedImage scaled(BufferedImage image,int w,int h) {
  BufferedImage out=new BufferedImage(w,h,BufferedImage.TYPE_INT_ARGB);Graphics2D g=out.createGraphics();
  g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
  g.drawImage(image,0,0,w,h,null);g.dispose();return out;
 }
 static Rectangle bounds(BufferedImage sheet,int x,int y,int w,int h) {
  int minX=w,minY=h,maxX=-1,maxY=-1;
  for(int j=0;j<h;j++)for(int i=0;i<w;i++)if((sheet.getRGB(x+i,y+j)>>>24)>32){minX=Math.min(minX,i);maxX=Math.max(maxX,i);minY=Math.min(minY,j);maxY=Math.max(maxY,j);}
  if(maxX<minX)throw new IllegalArgumentException("Missing sprite cell");
  return new Rectangle(x+minX,y+minY,maxX-minX+1,maxY-minY+1);
 }
 static void strip(BufferedImage sheet,Path file,int row,int count,int targetW,int targetH) throws Exception {
  int cellW=sheet.getWidth()/4,cellH=sheet.getHeight()/3;Rectangle[] frames=new Rectangle[count];
  int maxW=0,maxH=0;
  for(int i=0;i<count;i++){frames[i]=bounds(sheet,i*cellW,row*cellH,cellW,cellH);maxW=Math.max(maxW,frames[i].width);maxH=Math.max(maxH,frames[i].height);}
  int frameW=targetW/count;double scale=Math.min((frameW-2.0)/maxW,(targetH-1.0)/maxH);
  BufferedImage out=new BufferedImage(targetW,targetH,BufferedImage.TYPE_INT_ARGB);Graphics2D g=out.createGraphics();
  for(int i=0;i<count;i++){Rectangle b=frames[i];int w=Math.max(1,(int)Math.round(b.width*scale)),h=Math.max(1,(int)Math.round(b.height*scale));
   BufferedImage frame=scaled(sheet.getSubimage(b.x,b.y,b.width,b.height),w,h);g.drawImage(frame,i*frameW+(frameW-w)/2,targetH-h,null);
  }g.dispose();save(out,file);
 }
 public static void main(String[] args)throws Exception {
  Path out=Paths.get(args[3]);Files.createDirectories(out);
  int density=3;
  // Legacy assets keep their design, with integer scaling to preserve pixel geometry.
  ZipFile original=new ZipFile(args[4]);
  java.util.Enumeration<? extends ZipEntry> entries=original.entries();
  while(entries.hasMoreElements()) {
   ZipEntry entry=entries.nextElement();
   if(entry.getName().endsWith(".png")) {
    BufferedImage image=ImageIO.read(original.getInputStream(entry));
    save(scaled(image,image.getWidth()*density,image.getHeight()*density),out.resolve(entry.getName()));
   }
  }original.close();
  save(scaled(read(args[0]),176*density,166*density),out.resolve("cover7650r.png"));
  BufferedImage red=read(args[1]),teal=read(args[2]);
  strip(red,out.resolve("sarahstand2.png"),0,4,76*density,25*density);
  strip(red,out.resolve("sarahthrow2.png"),1,4,88*density,26*density);
  strip(red,out.resolve("sarahhit2.png"),2,2,54*density,31*density);
  strip(teal,out.resolve("vicstand2.png"),0,4,76*density,22*density);
  strip(teal,out.resolve("victhrow2.png"),1,4,80*density,24*density);
  strip(teal,out.resolve("vichit2.png"),2,2,52*density,34*density);
  // Inspection sheet at integer 8x scale, showing the exact game assets.
  BufferedImage preview=new BufferedImage(528,900,BufferedImage.TYPE_INT_ARGB);
  Graphics2D g=preview.createGraphics();g.setColor(new Color(14,21,45));g.fillRect(0,0,preview.getWidth(),preview.getHeight());
  g.drawImage(scaled(read(out.resolve("cover7650r.png").toString()),528,498),0,0,null);
  int y=510;
  for(String name:new String[]{"sarahstand2.png","vicstand2.png","sarahthrow2.png","victhrow2.png"}) {
   BufferedImage image=read(out.resolve(name).toString());g.drawImage(scaled(image,image.getWidth(),image.getHeight()),16,y,null);y+=image.getHeight()+16;
  }g.dispose();save(preview,out.resolve("packed-preview.png"));
 }
}
