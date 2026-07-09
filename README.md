# 🎮 Emulador CHIP-8 en C con SDL3

Un emulador del sistema **CHIP-8** escrito en C, utilizando **SDL3** para la renderización gráfica y el manejo de eventos de teclado. Este proyecto es una implementación desde cero de la máquina virtual CHIP-8, uno de los intérpretes de videojuegos más clásicos de la historia de la computación (originalmente de los años 70).

---

## 📖 ¿Qué es CHIP-8?

CHIP-8 es un **lenguaje interpretado de máquina virtual** diseñado en los años 70 por Joseph Weisbecker para facilitar el desarrollo de videojuegos en los microcomputadores de la época (como el COSMAC VIP y el Telmac 1800). Sus características principales son:

| Característica       | Valor                     |
|----------------------|---------------------------|
| Memoria RAM          | 4096 bytes (4 KB)         |
| Resolución de pantalla | 64 × 32 píxeles (monocromática) |
| Registros de datos   | 16 registros de 8 bits (V0–VF) |
| Registro I (índice)  | 16 bits                   |
| Profundidad de pila  | 16 niveles                |
| Teclas de entrada    | 16 teclas hexadecimales (0–F) |
| Temporizadores       | Delay timer + Sound timer |

---

## 🗂️ Estructura del Proyecto

```
chip8/
├── Makefile               # Sistema de build con GCC
├── bin/
│   └── main               # Ejecutable final (generado por make)
├── build/
│   ├── chip8memory.o      # Objetos compilados (generados por make)
│   ├── chip8stack.o
│   └── chip8keyboard.o
├── include/
│   ├── config.h           # Constantes globales de configuración
│   ├── chip8.h            # Estructura principal chip8 + init
│   ├── chip8memory.h      # API de la memoria
│   ├── chip8registers.h   # Estructura de registros
│   ├── chip8stack.h       # API de la pila (call stack)
│   └── chip8keyboard.h    # API del teclado
└── src/
    ├── main.c             # Punto de entrada, bucle principal SDL3
    ├── chip8.c            # Inicialización de la máquina
    ├── chip8memory.c      # Implementación de la memoria
    ├── chip8stack.c       # Implementación de la pila
    └── chip8keyboard.c    # Implementación del teclado
```

---

## ⚙️ Configuración Global — `include/config.h`

Este archivo centraliza todas las **constantes de configuración** del emulador. Al modificarlo se puede cambiar el comportamiento global sin tocar el resto del código.

```c
#define EMULATOR_WINDOW_TITLE   "Chip8 Emulator"
#define CHIP8_MEMORY_SIZE       4096   // Tamaño total de la RAM (bytes)
#define CHIP8_WIDTH             64     // Ancho de la pantalla en píxeles lógicos
#define CHIP8_HEIGHT            32     // Alto de la pantalla en píxeles lógicos
#define CHIP8_WINDOW_MULTIPLIER 10     // Factor de escala para la ventana SDL
#define CHIP8_TOTAL_DATA_REGISTERS 16  // Registros V0–VF
#define CHIP8_TOTAL_STACK_DEPTH    16  // Profundidad máxima de la pila
#define CHIP8_TOTAL_KEYS           16  // Teclas hexadecimales (0x0–0xF)
```

> **Nota:** La ventana final de SDL tiene un tamaño de `640 × 320` píxeles (64×10 × 32×10), escalando la baja resolución original de CHIP-8 a un tamaño moderno y visible.

---

## 🧠 Arquitectura de la Máquina — `include/chip8.h` / `src/chip8.c`

La estructura `chip8` es el **núcleo central** del emulador. Agrupa todos los componentes de hardware de la máquina virtual en un único objeto.

```c
struct chip8 {
    struct chip8_memory    memory;    // RAM de 4 KB
    struct chip8_registers registers; // Registros de la CPU
    struct chip8_stack     stack;     // Pila de llamadas
    struct chip8_keyboard  keyboard;  // Estado del teclado
};
```

### Inicialización

```c
void chip8_init(struct chip8* chip8) {
    memset(chip8, 0, sizeof(struct chip8));
}
```

La inicialización es simple y deliberada: se pone **toda la memoria a cero** con `memset`. Esto garantiza un estado limpio y predecible antes de cargar cualquier ROM. Es el equivalente a "encender" la máquina.

---

## 🗃️ Memoria — `include/chip8memory.h` / `src/chip8memory.c`

### Estructura

```c
struct chip8_memory {
    unsigned char memory[CHIP8_MEMORY_SIZE]; // Array de 4096 bytes
};
```

La memoria de CHIP-8 es un array plano de **4096 bytes** (`unsigned char`). Cada byte es direccionable individualmente.

### API

| Función | Descripción |
|---|---|
| `chip8_memory_set(memory, index, val)` | Escribe un byte en la posición `index` |
| `chip8_memory_get(memory, index)` | Lee un byte de la posición `index` |

### Seguridad de bounds

Ambas funciones llaman internamente a `chip8_is_memory_in_bounds(index)`:

```c
static void chip8_is_memory_in_bounds(int index) {
    assert(index >= 0 && index < CHIP8_MEMORY_SIZE);
}
```

Se usa `assert()` para **detener el programa** si se intenta acceder fuera del rango `[0, 4095]`. Esto convierte los errores de acceso ilegal en fallos inmediatos y detectables durante el desarrollo.

---

## 📋 Registros — `include/chip8registers.h`

```c
struct chip8_registers {
    unsigned char  V[CHIP8_TOTAL_DATA_REGISTERS]; // V0–VF (16 registros de 8 bits)
    unsigned short I;           // Registro índice (14 bits usados, 16 reservados)
    unsigned char  delay_timer; // Temporizador de retardo (cuenta a 60 Hz)
    unsigned char  sound_timer; // Temporizador de sonido (bip cuando > 0)
    unsigned short PC;          // Program Counter (puntero de instrucción)
    unsigned char  SP;          // Stack Pointer (índice en la pila)
};
```

### Descripción de cada registro

| Registro | Tamaño | Propósito |
|---|---|---|
| `V[0..15]` | 8 bits | Registros de propósito general. El último (`VF`) es el **flag de carry/borrow/colisión** |
| `I` | 16 bits | Registro de índice, apunta a direcciones de memoria (usado en gráficos y datos) |
| `delay_timer` | 8 bits | Se decrementa a 60 Hz; los juegos lo usan para temporización |
| `sound_timer` | 8 bits | Emite un bip mientras su valor sea mayor que 0; se decrementa a 60 Hz |
| `PC` | 16 bits | Apunta a la instrucción actual en memoria (normalmente inicia en `0x200`) |
| `SP` | 8 bits | Índice del siguiente espacio libre en la pila de llamadas |

---

## 📚 Pila de Llamadas — `include/chip8stack.h` / `src/chip8stack.c`

### Estructura

```c
struct chip8_stack {
    unsigned short stack[CHIP8_TOTAL_STACK_DEPTH]; // 16 entradas de 16 bits
};
```

La pila almacena **direcciones de retorno** cuando se ejecuta una instrucción de llamada a subrutina (`CALL`). Al retornar (`RET`), la dirección se recupera y se restaura el `PC`.

### API

| Función | Descripción |
|---|---|
| `chip8_stack_push(chip8, val)` | Guarda `val` en la cima de la pila e incrementa `SP` |
| `chip8_stack_pop(chip8)` | Decrementa `SP` y devuelve el valor en la cima |

### Implementación

```c
void chip8_stack_push(struct chip8* chip8, unsigned short val) {
    chip8_stack_in_bounds(chip8);              // Verifica que SP < 16
    chip8->stack.stack[chip8->registers.SP] = val;
    chip8->registers.SP += 1;
}

unsigned short chip8_stack_pop(struct chip8* chip8) {
    chip8->registers.SP -= 1;
    chip8_stack_in_bounds(chip8);              // Verifica que SP >= 0
    return chip8->stack.stack[chip8->registers.SP];
}
```

> **Nota de diseño:** La función `chip8_stack_in_bounds` recibe el `struct chip8*` completo (no solo el stack) porque necesita acceder al registro `SP` que vive en `chip8->registers`. Esto ejemplifica la cohesión entre componentes.

---

## ⌨️ Teclado — `include/chip8keyboard.h` / `src/chip8keyboard.c`

El CHIP-8 original tenía un **teclado hexadecimal de 16 teclas** (de `0` a `F`).

### Estructura

```c
struct chip8_keyboard {
    bool keyboard[CHIP8_TOTAL_KEYS]; // Estado de cada tecla: true = presionada
};
```

Un array de booleans donde cada índice representa una tecla CHIP-8 (0x0 a 0xF). `true` significa que la tecla está actualmente presionada.

### API

| Función | Descripción |
|---|---|
| `chip8_keyboard_map(map, key)` | Convierte un keycode de SDL al índice CHIP-8 (0–15), o `-1` si no está mapeada |
| `chip8_keyboard_down(keyboard, key)` | Marca la tecla `key` como presionada |
| `chip8_keyboard_up(keyboard, key)` | Marca la tecla `key` como liberada |
| `chip8_keyboard_is_down(keyboard, key)` | Devuelve `true` si la tecla está presionada |

### Mapeo de teclas

En `main.c` se define la tabla de mapeo entre teclas del teclado físico (SDL) y el teclado virtual CHIP-8:

```
Teclado CHIP-8 original:      Mapeo en este emulador:
┌───┬───┬───┬───┐             ┌───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ C │             │ 1 │ 2 │ 3 │ 4 │
├───┼───┼───┼───┤             ├───┼───┼───┼───┤
│ 4 │ 5 │ 6 │ D │             │ Q │ W │ E │ R │
├───┼───┼───┼───┤  ────────▶  ├───┼───┼───┼───┤
│ 7 │ 8 │ 9 │ E │             │ A │ S │ D │ F │
├───┼───┼───┼───┤             ├───┼───┼───┼───┤
│ A │ 0 │ B │ F │             │ Z │ X │ C │ V │
└───┴───┴───┴───┘             └───┴───┴───┴───┘
```

La tabla en el código mapea directamente los SDL keycodes a índices CHIP-8:

```c
// main.c
const unsigned char keyboard_map[CHIP8_TOTAL_KEYS] = {
    SDLK_0, SDLK_1, SDLK_2, SDLK_3,
    SDLK_4, SDLK_5, SDLK_6, SDLK_7,
    SDLK_8, SDLK_9, SDLK_A, SDLK_B,
    SDLK_C, SDLK_D, SDLK_E, SDLK_F
};
```

---

## 🖥️ Bucle Principal — `src/main.c`

El `main.c` es el punto de entrada y orquesta la inicialización, el bucle de eventos SDL y el renderizado.

### Flujo de ejecución

```
main()
  │
  ├─ 1. chip8_init()          → Inicializa toda la máquina (memset a 0)
  │
  ├─ 2. SDL_Init()            → Inicializa el subsistema de video
  ├─ 3. SDL_CreateWindow()    → Crea ventana de 640×320 px
  ├─ 4. SDL_CreateRenderer()  → Crea renderer de hardware 2D
  │
  └─ 5. Bucle principal (while 1):
         │
         ├─ PollEvent → SDL_EVENT_QUIT  → goto out (termina)
         ├─ PollEvent → KEY_DOWN        → chip8_keyboard_map() + chip8_keyboard_up()
         ├─ PollEvent → KEY_UP          → (log de consola, pendiente de implementar)
         │
         ├─ SDL_RenderClear()           → Limpia la pantalla (negro)
         ├─ SDL_RenderFillRect()        → Dibuja un rectángulo blanco de prueba (40×40)
         └─ SDL_RenderPresent()         → Presenta el frame renderizado
         │
  out:  SDL_DestroyRenderer() + SDL_DestroyWindow() + SDL_Quit()
```

### Manejo de eventos de teclado

```c
case SDL_EVENT_KEY_DOWN: {
    SDL_Keycode key = event.key.key;
    int vkey = chip8_keyboard_map(keyboard_map, (char)key);  // SDL → CHIP-8
    if (vkey != -1) {
        chip8_keyboard_up(&chip8.keyboard, vkey);  // ← BUG: debería ser _down
    }
}
```

> **⚠️ Observación:** En el evento `KEY_DOWN` se llama a `chip8_keyboard_up()` en lugar de `chip8_keyboard_down()`. Esto parece un bug tipográfico en la implementación actual — la tecla queda marcada como "liberada" cuando en realidad se acaba de presionar.

---

## 🔨 Sistema de Build — `Makefile`

El proyecto usa **GNU Make** con **GCC** para compilar. Las dependencias de SDL3 se resuelven mediante una biblioteca precompilada en `./lib/`.

### Variables

```makefile
CC      = gcc
CFLAGS  = -g -I./include      # Compilar con debug info + incluir ./include
LIBS    = -L./lib -lSDL3      # Linkar la librería SDL3 desde ./lib
```

### Targets

| Target | Comando | Descripción |
|---|---|---|
| `all` (default) | `make` | Compila todos los `.o` y linkea el ejecutable final en `./bin/main` |
| `build/chip8memory.o` | — | Compila `chip8memory.c` |
| `build/chip8stack.o` | — | Compila `chip8stack.c` |
| `build/chip8keyboard.o` | — | Compila `chip8keyboard.c` |
| `clean` | `make clean` | Elimina todos los `.o` de `./build/` |

### Orden de compilación

```
chip8memory.c  ──→  chip8memory.o  ──┐
chip8stack.c   ──→  chip8stack.o   ──┼──→  main (linkeo final)
chip8keyboard.c──→  chip8keyboard.o──┘
main.c (compilado directamente en el paso de linkeo)
```

> **Nota:** `chip8.c` tiene su regla de compilación definida en el Makefile, pero **no está incluido** en la variable `OBJECTS`. Esto significa que actualmente `chip8_init()` se puede estar linkedando de forma implícita o que es una omisión pendiente de corregir.

---

## 🧩 Diagrama de Dependencias entre Módulos

```
                    ┌─────────────┐
                    │   config.h  │  (constantes globales)
                    └──────┬──────┘
           ┌───────────────┼────────────────────┐
           ▼               ▼                    ▼
    ┌─────────────┐ ┌──────────────┐ ┌──────────────────┐
    │chip8memory.h│ │chip8registers│ │  chip8keyboard.h  │
    └──────┬──────┘ └──────┬───────┘ └────────┬─────────┘
           │               │                  │
           │        ┌──────▼───────┐          │
           │        │ chip8stack.h │          │
           │        └──────┬───────┘          │
           └───────────────┼──────────────────┘
                           ▼
                    ┌─────────────┐
                    │   chip8.h   │  (struct chip8 agrega todo)
                    └──────┬──────┘
                           ▼
                    ┌─────────────┐
                    │   main.c    │  (SDL3 + bucle principal)
                    └─────────────┘
```

---

## 🚀 Estado Actual y Próximos Pasos

El proyecto se encuentra en una **fase inicial de andamiaje (scaffolding)**. La arquitectura de la máquina virtual está definida y los módulos de hardware están implementados. Lo que falta:

### ✅ Implementado
- [x] Configuración global (`config.h`)
- [x] Estructura central `chip8` con todos sus componentes
- [x] Módulo de memoria con bounds checking (`assert`)
- [x] Registros de CPU (V0–VF, I, PC, SP, timers)
- [x] Pila de llamadas con push/pop
- [x] Teclado con mapeo SDL → CHIP-8
- [x] Ventana SDL3 y renderer básico
- [x] Bucle de eventos SDL (quit + teclado)

### 🔲 Pendiente de implementar
- [ ] **Pantalla/Display**: Buffer de píxeles 64×32 y lógica de renderizado de sprites XOR
- [ ] **Cargador de ROMs**: Leer archivos `.ch8` y cargarlos en memoria a partir de `0x200`
- [ ] **CPU / Fetch-Decode-Execute**: Ciclo de instrucción completo con todas las ~35 opcodes de CHIP-8
- [ ] **Font set**: Cargar los sprites de dígitos hexadecimales (0–F) en la zona reservada de memoria (`0x000–0x1FF`)
- [ ] **Temporizadores**: Decrementar `delay_timer` y `sound_timer` a 60 Hz
- [ ] **Sonido**: Integrar SDL_AudioStream para el bip del `sound_timer`
- [ ] **Fix bug**: Corregir `chip8_keyboard_up` → `chip8_keyboard_down` en el evento `KEY_DOWN`
- [ ] **Fix build**: Agregar `chip8.o` a la variable `OBJECTS` del Makefile

---

## 🛠️ Cómo Compilar y Ejecutar

### Requisitos
- **GCC** (MinGW en Windows)
- **SDL3** (la DLL/SO debe estar disponible en el PATH o en `./lib/`)
- **GNU Make**

### Compilar

```bash
make
```

Genera el ejecutable en `./bin/main`.

### Limpiar objetos

```bash
make clean
```

### Ejecutar

```bash
./bin/main
```

> En Windows, asegúrate de que `SDL3.dll` esté en el mismo directorio que el ejecutable o en el PATH del sistema.

---

## 📚 Referencias y Recursos

- [Cowgod's CHIP-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM) — La referencia técnica más completa del CHIP-8
- [SDL3 Documentation](https://wiki.libsdl.org/SDL3/) — Documentación oficial de SDL3
- [CHIP-8 Wikipedia](https://en.wikipedia.org/wiki/CHIP-8) — Historia y especificaciones generales
- [Tobias V. Langhoff — Guide to making a CHIP-8 emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/) — Guía práctica moderna
