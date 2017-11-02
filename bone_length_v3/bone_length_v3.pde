import java.util.Collections;
import java.util.Comparator;

PImage oImg, bImg, eImg, dImg, background, dilImage, closingImage;
Point spoint = new Point();
Point epoint = new Point();
String imageName;
ArrayList<ROI> found;
float depth, epixels;
float threshold = 0.60;
float length_filter = 0.70;
int dx[] = {-1, 0, 1, -1, 1, -1, 0, 1};
int dy[] = {-1, -1, -1, 0, 0, 1, 1, 1};
int count = 0;
PImage output;

class Point {
  int x, y;
}

class ROI{
  ArrayList<Integer> x = new ArrayList<Integer>();
  ArrayList<Integer> y = new ArrayList<Integer>();
  ArrayList<Integer> ex = new ArrayList<Integer>();
  ArrayList<Integer> ey = new ArrayList<Integer>();
  Point p1 = new Point();
  Point p2 = new Point();
  Point p3 = new Point();
  Point p4 = new Point();
  float len, curvture = 0.0;
  String shape;
  int w,h;
  
  public ROI() {
  }
  
  public ROI(int w, int h) {
    this.w = w;
    this.h = h;
  }
  
  public void addPoint(int x, int y) {
    this.x.add(x);
    this.y.add(y);
    int loc = y * dImg.width + x;
    if(dImg.pixels[loc] == color(255)) {
      this.ex.add(x);
      this.ey.add(y);
    }
  }
  
  public void calculateEndPoint() {
    len = 0;
    for(int i = 0; i < ex.size(); i++)
      for(int j = 0; j < ey.size(); j++) {
        float distance = eulerDistance((float)ex.get(i), (float)ey.get(i),
                                      (float)ex.get(j), (float)ey.get(j));
        if(distance > len) {
          len = distance;
          p1.x = ex.get(i);
          p1.y = ey.get(i);
          p2.x = ex.get(j);
          p2.y = ey.get(j);
        }
      }
  }
  
  public void calculateCurvture() {
    float maxDis = 0;
    float x1 = (float)p1.x, x2 = (float)p2.x;
    float y1 = (float)p1.y, y2 = (float)p2.y;
    for(int i = 0; i < ex.size(); i++) {
      float x0 = (float)ex.get(i);
      float y0 = (float)ey.get(i);
      float dis = (abs((y2 - y1) * x0 +(x1 - x2) * y0 + ((x2 * y1) -(x1 * y2)))) / (sqrt(pow(y2 - y1, 2.0) + pow(x1 - x2, 2.0)));
      if(dis > maxDis) {
        maxDis = dis;
        p3.x = ex.get(i);
        p3.y = ey.get(i);
      }
      
    } //<>//
    curvture = maxDis / len; //<>//
  }
  
  public void checkShape() {
    if(curvture > 0.1) shape = "circle";
    else shape = "line";
  }
}

float eulerDistance(float x1, float y1, float x2, float y2) {
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

void setup(){
  frameRate(64);
  fullScreen();
  loadConfigureFiles();
  oImg = loadImage(imageName);
  bImg = convertToBinaryImage(oImg, threshold);
  dilImage = getDilation(bImg);
  closingImage = getErosion(dilImage);
  eImg = getErosion(closingImage);
  dImg = getDifferenceImage(closingImage, eImg);
  
  found = detectROI(closingImage);
  System.out.println(found.size());
  image(oImg, 0, 0);
  for(int i = 0; i < found.size(); i++) {
    ROI roi = found.get(i);
    roi.calculateEndPoint();
    roi.calculateCurvture();
    roi.checkShape();
  } //<>//
  sortROIs(found);
  for(int i = 0; i < 3; i++) {
    System.out.println("Length of " + i + ": " + getRealLength(found.get(i).len));
    System.out.println("Shape: " + found.get(i).shape);
    System.out.println("Curvture: " + found.get(i).curvture);
  }
  background = oImg.copy();
  updateBackgroundImage();
}

void updateBackgroundImage() {
  background.loadPixels();
  dImg.loadPixels();
  for(int i = 0; i < found.size(); i++) {
    ROI roi = found.get(i);
    if(getRealLength(roi.len) <= length_filter * getRealLength(found.get(0).len)){
      break;
    }
    for(int j = 0; j < roi.y.size(); j++){
          int nx = roi.x.get(j);
          int ny = roi.y.get(j);
          int loc = ny * background.width + nx;
          if(dImg.pixels[loc] != color(0)) {
            background.pixels[loc] = color(255, 255, 0);
          }
    }
  }
  background.updatePixels();
  
  visualise();
}

void visualise() {
  
  image(background, 0, 0);
  
  stroke(255, 0, 0);
  strokeWeight(3);
  textSize(15);
  fill(255, 0, 0);
  for(int i = 1; i < found.size(); i++) {
    ROI roi = found.get(i);
    ROI proi = found.get(i-1);
    if(roi.shape == "circle" && proi.shape == "circle") {
      float dx = (float)roi.p3.x - (float)proi.p3.x;
      float dy = (float)roi.p3.y - (float)proi.p3.y;
      float dis = sqrt(dx * dx + dy * dy);
      float realDis = getRealLength(dis);
      int ty = (roi.p3.y + proi.p3.y) / 2;
      int tx = roi.p3.x < proi.p3.x ? proi.p3.x : roi.p3.x;
      line(roi.p3.x, roi.p3.y, proi.p3.x, proi.p3.y);
      text(String.format("%.2f",realDis) + "mm", tx, ty);
      return ;
    }
    if(getRealLength(roi.len) <= length_filter * getRealLength(found.get(0).len)){
      break;
    }
  }
  for(int i = 0; i < found.size(); i++) {
    ROI roi = found.get(i);
    if(getRealLength(roi.len) <= length_filter * getRealLength(found.get(0).len)){
      break;
    } else {
      int ty = roi.p1.y < roi.p2.y ? roi.p1.y : roi.p2.y;
      int tx = (roi.p1.x + roi.p2.x) / 2;
      line(roi.p1.x, roi.p1.y, roi.p2.x, roi.p2.y);
      text(String.format("%.2f",getRealLength(found.get(i).len)) + "mm", tx, ty);    
    }
  }
}

void draw() {
}

void mouseClicked() {
  if(count == 0) {
    stroke(0, 255, 255);
    strokeWeight(3);
    spoint.x = mouseX;
    spoint.y = mouseY;
    point(spoint.x, spoint.y);
    count = 1;
  } else {
    epoint.x = mouseX;
    epoint.y = mouseY;
    float dis = eulerDistance((float)spoint.x, (float)spoint.y, 
                              (float)epoint.x, (float)epoint.y);
    float realDis = getRealLength(dis);
    stroke(0, 255, 255);
    strokeWeight(3);
    textSize(15);
    fill(0, 255, 255);
    line(spoint.x, spoint.y, epoint.x, epoint.y);
    text(String.format("%.2f", realDis) + "mm", spoint.x, spoint.x);
    count = 0;
  }
  
}

PImage getErosion(PImage oImg) {
  PImage rImg = oImg.copy();
  
  rImg.loadPixels();
  oImg.loadPixels();
  
  for(int y = 0; y < oImg.height; y++) 
    for(int x = 0; x < oImg.width; x++) {
      int loc = y * oImg.width + x;
      for(int i = 0; i < 8; i++) {
        int nx = x + dx[i];
        int ny = y + dy[i];
        int nloc = ny * oImg.width + nx;
        if(checkRange(nx, ny, oImg.width, oImg.height)) {
          if(oImg.pixels[nloc] == color(0)){
            rImg.pixels[loc] = color(0);
            break;
          }
        }
      }
    }
  rImg.updatePixels();
  return rImg;
}

PImage getDilation(PImage oImg) { 
  PImage rImg = oImg.copy();
  
  rImg.loadPixels();
  oImg.loadPixels();
  
  for(int y = 0; y < oImg.height; y++) 
    for(int x = 0; x < oImg.width; x++) {
      int loc = y * oImg.width + x;
      for(int i = 0; i < 8; i++) {
        int nx = x + dx[i];
        int ny = y + dy[i];
        int nloc = ny * oImg.width + nx;
        if(checkRange(nx, ny, oImg.width, oImg.height)) {
          if(oImg.pixels[nloc] == color(255)){
            rImg.pixels[loc] = color(255);
            break;
          }
        }
      }
    }
  rImg.updatePixels();
  return rImg;
}

PImage getDifferenceImage(PImage img1, PImage img2) {
  PImage rImg = img1.copy();
  rImg.loadPixels();
  img1.loadPixels();
  img2.loadPixels();
  
  for(int y = 0; y < oImg.height; y++) 
    for(int x = 0; x < oImg.width; x++) {
      int loc = y * oImg.width + x;
      if(img1.pixels[loc] == img2.pixels[loc]){
        rImg.pixels[loc] = color(0);
      } else {
        rImg.pixels[loc] = color(255);
      }
    }
  
  rImg.updatePixels();
  
  return rImg;
}

void sortROIs(ArrayList<ROI> input) {
  Collections.sort(input, new Comparator<ROI>() {
        @Override
        public int compare(ROI o1, ROI o2)
        {
          if(getRealLength(o1.len) < getRealLength(o2.len))
            return 1;
          return -1;
        }
    });
}

void loadConfigureFiles() {
  String[] config = loadStrings("bone_length.config");
  for(int i = 0; i < config.length; i++) {
    String line = config[i];
    if(line.startsWith("#")) continue;
    if(line.startsWith("image")) {
      String[] para = line.split("=");
      imageName = para[para.length - 1];
    } else if (line.startsWith("depth")) {
      String[] para = line.split("=");
      depth = Float.parseFloat(para[para.length - 1]);
    } else if (line.startsWith("equivalent-pixels")) {
      String[] para = line.split("=");
      epixels = Float.parseFloat(para[para.length - 1]);
    } else if (line.startsWith("threshold")) {
      String[] para = line.split("=");
      threshold = Float.parseFloat(para[para.length - 1]);
    } else if (line.startsWith("length-threshold")) {
      String[] para = line.split("=");
      length_filter = Float.parseFloat(para[para.length - 1]);
    }
  }
}

PImage convertToBinaryImage(PImage oImg, float threshold) {
  PImage rImg= oImg.copy();
  float maxV = 0;
  
  rImg.loadPixels();
  oImg.loadPixels();
  
  for(int y = 0; y < oImg.height; y++) 
    for(int x = 0; x < oImg.width; x++) {
      int loc = y * oImg.width + x;
      float oPValue = getPixelValue(oImg.pixels[loc]);
      if(maxV < oPValue) maxV = oPValue;
    }
  for(int y = 0; y < oImg.height; y++) 
    for(int x = 0; x < oImg.width; x++) {
      int loc = y * oImg.width + x;
      float oPValue = getPixelValue(oImg.pixels[loc]);
      if(oPValue < maxV * threshold) {
        rImg.pixels[loc] = color(0);
      } else {
        rImg.pixels[loc] = color(255);
      }
    }
  return rImg;
}

float getPixelValue(color o) {
  float r = (float) red(o);
  float g = (float) green(o);
  float b = (float) blue(o);
  
  return 0.2989 * r + 0.5870 * g + 0.1140 * b;
}

ArrayList<ROI> detectROI(PImage bImg) {
  ArrayList<ROI> result = new ArrayList<ROI>();
  boolean map[][] = new boolean[bImg.height][bImg.width];
  
  for(int y = 0; y < bImg.height; y++) 
    for(int x = 0; x < bImg.width; x++) {
      map[y][x] = true;
    }
  
  bImg.loadPixels();
  for(int y = 0; y < bImg.height; y++) 
    for(int x = 0; x < bImg.width; x++) {
      if(map[y][x]) {
        int loc = y * bImg.width + x;
        if(bImg.pixels[loc] == color(0)) {
          map[y][x] = false;
          continue;
        } else {
          int head = 0, tail = 0;
          ROI roi = new ROI(bImg.width, bImg.height);
          int xque[] = new int[bImg.height * bImg.width];
          int yque[] = new int[bImg.height * bImg.width];
          xque[tail] = x;
          yque[tail++] = y;
          roi.addPoint(x, y);
          
          while(head < tail) {
            int cx = xque[head];
            int cy = yque[head];
            for(int i = 0; i < 8; i++) {
              int nx = cx + dx[i];
              int ny = cy + dy[i];
              int nloc = ny * bImg.width + nx;
              if(checkRange(nx, ny, bImg.width, bImg.height)
              && bImg.pixels[nloc] == color(255)
              && map[ny][nx]) {
                xque[tail] = nx;
                yque[tail++] = ny;
                roi.addPoint(nx, ny);
                map[ny][nx] = false;
              }
            }
            head++;
          }
          result.add(roi);
        }
      }
    }
  return result;
}

boolean checkRange(int x, int y, int lx, int ly) {
  if(x >= 0 && x < lx && y >=0 && y < ly) return true;
  return false;
}

float getRealLength(float lengths) {
  return lengths * depth / epixels; 
}