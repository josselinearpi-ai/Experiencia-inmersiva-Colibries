import processing.video.*;
import processing.sound.*;

// --- Configuración de Vídeo y Cámara ---
Capture cam;
PImage oldFrame; 
float thresholdMovimiento = 25.0; 

// --- Configuración de Audio/Ruido ---
AudioIn mic;
Amplitude analyzer;
float thresholdRuido = 0.05; 

boolean yaRegistroRuido = false; 
float anguloActual = 0; 

// --- Configuración de los Colibríes ---
ArrayList<Colibri> bandadaRuido;
Colibri colibriInteractivo; 

float personaX;
float personaY;

void setup() {
  size(1920, 1080); // CORREGIDO: 1920px de largo (ancho) por 1080px de alto
  
  // Inicializar Cámara
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("No hay cámaras disponibles.");
  } else {
    cam = new Capture(this, 640, 480, cameras[0]);
    cam.start();
  }
  
  oldFrame = createImage(640, 480, RGB); 
  
  personaX = width / 2;
  personaY = height / 2;
  
  bandadaRuido = new ArrayList<Colibri>();
  
  // El colibrí interactivo principal
  colibriInteractivo = new Colibri(personaX, personaY, true); 
  
  // Inicializar Audio
  mic = new AudioIn(this, 0);
  mic.start();
  analyzer = new Amplitude(this);
  analyzer.input(mic);
}

void draw() {
  dibujarFondoMistico(); 
  
  // --- Procesar Cámara e Interacción Humana ---
  if (cam != null && cam.available()) {
    oldFrame.copy(cam, 0, 0, cam.width, cam.height, 0, 0, oldFrame.width, oldFrame.height);
    oldFrame.updatePixels();
    cam.read();
    
    PVector puntoHumano = calcularPuntoMaximoMovimiento();
    if (puntoHumano != null) {
      personaX = lerp(personaX, puntoHumano.x, 0.15);
      personaY = lerp(personaY, puntoHumano.y, 0.15);
    }
  }
  
  // --- Procesar Ruido ---
  float volumen = analyzer.analyze();
  
  if (volumen > thresholdRuido) {
    if (!yaRegistroRuido) {
      anguloActual += random(PI * 0.8, PI * 1.2); 
      
      float radioX = width * 0.45;
      float radioY = height * 0.45;
      float xAleatorio = (width / 2) + cos(anguloActual) * radioX;
      float yAleatorio = (height / 2) + sin(anguloActual) * radioY;
      
      xAleatorio = constrain(xAleatorio, 50, width - 50);
      yAleatorio = constrain(yAleatorio, 50, height - 50);
      
      bandadaRuido.add(new Colibri(xAleatorio, yAleatorio, false));
      yaRegistroRuido = true; 
    }
  } else {
    yaRegistroRuido = false; 
  }
  
  // --- CAPA 1: Colibríes de Ruido ---
  for (int i = bandadaRuido.size() - 1; i >= 0; i--) {
    Colibri c = bandadaRuido.get(i);
    c.updateAutonomo(); 
    
    if (c.updateFade()) {
      bandadaRuido.remove(i);
    } else {
      c.display();
    }
  }
  
  // --- CAPA 2: Colibrí Interactivo Principal ---
  colibriInteractivo.updateInteractivo(personaX, personaY);
  colibriInteractivo.display();
}

// --- Algoritmo de Punto de Mayor Movimiento ---
PVector calcularPuntoMaximoMovimiento() {
  cam.loadPixels();
  oldFrame.loadPixels();
  
  float maxDiferencia = 0;
  int maxX = -1;
  int maxY = -1;
  
  for (int x = 0; x < cam.width; x += 4) {
    for (int y = 0; y < cam.height; y += 4) {
      int loc = x + y * cam.width;
      color current = cam.pixels[loc];
      color previous = oldFrame.pixels[loc];
      
      float d = dist(red(current), green(current), blue(current), red(previous), green(previous), blue(previous));
      
      if (d > thresholdMovimiento && d > maxDiferencia) {
        maxDiferencia = d;
        maxX = x;
        maxY = y;
      }
    }
  }
  
  if (maxX != -1 && maxY != -1) {
    float mappedX = map(maxX, 0, cam.width, width, 0); 
    float mappedY = map(maxY, 0, cam.height, 0, height);
    return new PVector(mappedX, mappedY);
  }
  
  return null; 
}

// --- Fondo Oscuro ---
void dibujarFondoMistico() {
  for (int i = 0; i < height; i++) {
    float n = map(i, 0, height, 0, 1);
    color c = lerpColor(color(10, 25, 15), color(5, 15, 10), n);
    stroke(c);
    line(0, i, width, i);
  }
}

// --- Clase Colibri ---
class Colibri {
  PVector posicion;
  PVector velocidad;
  PVector destinoAutonomo; 
  boolean esInteractivo;
  float seed;
  float tamano; 
  float direccionHorizontal; 
  float opacidad; 
  float velocidadMaxima;
  float fuerzaGiro;

  Colibri(float startX, float startY, boolean interactivo) {
    posicion = new PVector(startX, startY);
    velocidad = new PVector(0, 0);
    esInteractivo = interactivo;
    seed = random(1000);
    tamano = esInteractivo ? 0.95 : random(0.45, 0.6);
    direccionHorizontal = 1;
    opacidad = 255; 
    
    velocidadMaxima = esInteractivo ? 14.0 : random(3.5, 5.5);
    fuerzaGiro = esInteractivo ? 0.12 : random(0.02, 0.05); 
    
    if (!esInteractivo) {
      nuevoDestinoAleatorio();
    }
  }

  void nuevoDestinoAleatorio() {
    destinoAutonomo = new PVector(random(80, width - 80), random(80, height - 80));
  }

  boolean updateFade() {
    if (!esInteractivo) {
      opacidad -= 0.8; 
      if (opacidad <= 0) {
        return true; 
      }
    }
    return false;
  }

  void updateAutonomo() {
    if (!esInteractivo) {
      PVector direccion = PVector.sub(destinoAutonomo, posicion);
      float distancia = direccion.mag();

      if (distancia < 50 || random(100) < 1.0) {
        nuevoDestinoAleatorio();
      }

      direccion.normalize();
      direccion.mult(velocidadMaxima); 
      
      velocidad.lerp(direccion, fuerzaGiro); 
      posicion.add(velocidad);
      
      if (velocidad.x > 0.3) {
        direccionHorizontal = -1; 
      } else if (velocidad.x < -0.3) {
        direccionHorizontal = 1;  
      }
    }
  }

  void updateInteractivo(float tx, float ty) {
    if (esInteractivo) {
      opacidad = 255; 
      
      PVector objetivo = new PVector(tx, ty);
      PVector direccion = PVector.sub(objetivo, posicion);
      float distancia = direccion.mag();

      if (distancia > 5) { 
        direccion.normalize();
        direccion.mult(velocidadMaxima); 
        velocidad.lerp(direccion, fuerzaGiro); 
        posicion.add(velocidad);
        
        if (velocidad.x > 0.1) {
          direccionHorizontal = -1; 
        } else if (velocidad.x < -0.1) {
          direccionHorizontal = 1;  
        }
      } else {
        velocidad.mult(0.2); 
      }
    }
  }

  void display() {
    pushMatrix();
    translate(posicion.x, posicion.y);
    scale(tamano);
    scale(direccionHorizontal, 1);

    float rapidezAleteo = esInteractivo ? 3.2 : random(1.8, 2.4);
    float flap = sin(frameCount * rapidezAleteo) * 0.7;
    
    float hover = sin(frameCount * 0.08 + seed) * 12;
    translate(0, hover);

    dibujarCola();
    dibujarAlaTrasera(flap);
    dibujarCuerpoYCabeza();
    dibujarAlaDelantera(flap);
    dibujarPico();
    
    popMatrix();
  }

  void dibujarCuerpoYCabeza() {
    noStroke();
    fill(10, 30, 80, opacidad); 
    ellipse(0, 0, 120, 60);
    fill(0, 60, 160, opacidad); 
    ellipse(-60, -10, 50, 50);

    randomSeed((long)seed);
    for (int i = 0; i < 150; i++) {
      float px = random(-95, 30);
      float py = random(-35, 25);
      if (pow(px/60, 2) + pow(py/30, 2) <= 1 || dist(px, py, -60, -10) < 25) {
        float t = map(px, -95, 30, 0, 1);
        color colorPunto = lerpColor(color(0, 230, 255), color(15, 50, 160), t);
        fill(colorPunto, map(opacidad, 0, 255, 0, random(180, 255)));
        ellipse(px, py, random(4, 7), random(4, 7));
      }
    }
    fill(0, opacidad); ellipse(-70, -15, 8, 8); 
    fill(255, opacidad); ellipse(-72, -17, 2, 2); 
  }

  void dibujarAlaDelantera(float flap) {
    pushMatrix();
    translate(-10, -20);
    rotate(flap);
    noStroke();
    fill(0, 100, 255, map(opacidad, 0, 255, 0, 180));
    beginShape();
    vertex(0, 0);
    bezierVertex(20, -100, 40, -150, 10, -170);
    bezierVertex(-20, -140, -30, -60, 0, 0);
    endShape(CLOSE);
    stroke(150, 240, 255, map(opacidad, 0, 255, 0, 150)); line(0, 0, 10, -160); 
    popMatrix();
  }

  void dibujarAlaTrasera(float flap) {
    pushMatrix();
    translate(10, -25);
    rotate(flap + 0.3);
    noStroke();
    fill(0, 50, 120, map(opacidad, 0, 255, 0, 100));
    beginShape();
    vertex(0, 0);
    bezierVertex(15, -90, 35, -130, 5, -150);
    bezierVertex(-15, -120, -25, -50, 0, 0);
    endShape(CLOSE);
    popMatrix();
  }

  void dibujarCola() {
    pushMatrix();
    translate(55, 12);
    for (int i = 0; i < 4; i++) {
      rotate(0.12);
      fill(5, 20, 60, opacidad); rect(0, -6, 90, 12, 5);
      fill(0, 180, 255, opacidad); rect(15, -2, 70, 4, 2);
    }
    popMatrix();
  }

  void dibujarPico() {
    stroke(10, 30, 50, opacidad); strokeWeight(3.5);
    line(-85, -10, -185, 30);
  }
}
