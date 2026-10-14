#include "jvm.h"
#include "jvm_util.h"
#include "j2me_render.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
void delta_j2me_configure_2d(int,int);
static const char *capture_path;
static void capture(void *image,int width,int height) {
 if(!image)return;
 if(capture_path) {
  CFURLRef url=CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8 *)capture_path,strlen(capture_path),false);
  CGImageDestinationRef out=CGImageDestinationCreateWithURL(url,CFSTR("public.png"),1,NULL);
  if(out){CGImageDestinationAddImage(out,(CGImageRef)image,NULL);CGImageDestinationFinalize(out);CFRelease(out);}
  CFRelease(url);
 }
 CFRelease(image);
}
int main(int argc,char **argv) {
 if(argc<7)return 64;
 delta_j2me_configure_2d(atoi(argv[4]),atoi(argv[5]));
 capture_path=argc>7?argv[7]:NULL;
 MiniJVM *vm=jvm_create();vm->jdwp_enable=0;vm->max_heap_size=128*1024*1024;
 vm->garbage_collect_period_ms=500;vm->heap_overload_percent=70;
 int result=jvm_init(vm,argv[1],argv[2]);if(result)return result;
 j2me_render_reg_natives(vm);j2me_render_set_flush_callback(capture);
 sys_properties_set_c(vm,"app.save.root",argv[6]);
 ArrayList *args=arraylist_create(0);result=call_main(vm,argv[3],args);fflush(stdout);return result;
}
