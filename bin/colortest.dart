import 'dart:io';

void main(List<String> arguments) {
  colorTest();
}

void colorTest() {
  // 216 colors
  int count=0;
  for(int i=16; i<=255; i++) {
    stdout.write("\x1b[48;5;${i}m ${i.toString().padLeft(3,' ')} \x1B[0m");
    if(++count == 8) {
      count=0;
      stdout.write("\n");
    }
  }
  stdout.write("\x1B[0m\n");


  //basic 8 + bright
  count=0;
  print("Basic 8 + bright");
  for(int i=0; i<=15; i++) {
    stdout.write("\x1b[38;5;${i}m ${i.toString().padLeft(3,' ')} \x1B[0m");
    if(++count == 8) {
      count=0;
      stdout.write("\n");
    }
  }
  stdout.write("\x1B[0m\n");

  //grey
  count=0;
  print("Greyscale");
  for(int i=232; i<=255; i++) {
    stdout.write("\x1b[48;5;${i}m ${i.toString().padLeft(3,' ')} \x1B[0m");
    if(++count == 8) {
      count=0;
      stdout.write("\n");
    }
  }
  stdout.write("\x1B[0m\n");

  //RGB colors
  print("RGB Red 8 steps");
  stdout.write("\x1b[37m");//white text
  count=0;
  for(int r=0; r<256; r+=32) {
    stdout.write("\x1b[37m");//white text
    stdout.write("\x1b[48;2;${r};0;0m ${r.toString().padLeft(3,' ')} \x1B[0m");
    if(++count == 8) {
      count=0;
      stdout.write("\n");
    }
  }
  stdout.write("\x1B[0m\n");
}
