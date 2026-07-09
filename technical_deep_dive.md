# 🔬 CHIP-8 Emulator — Deep Technical Dive

> Un análisis exhaustivo de **cada decisión técnica** en el código: por qué se eligió cada tipo de dato, cada constante hexadecimal, cada estructura de datos y cada algoritmo. Este documento asume que sabes C, pero explica el *razonamiento detrás* de cada línea.

---

## Tabla de Contenidos

1. [El sistema numérico hexadecimal en contexto de emulación](#1-el-sistema-hexadecimal-y-por-qué-domina-la-emulación)
2. [Por qué `unsigned char` y no `int` — la guerra de tipos](#2-por-qué-unsigned-char-y-no-int--la-guerra-de-tipos)
3. [Por qué `unsigned short` para PC, I y el stack](#3-por-qué-unsigned-short-para-pc-i-y-el-stack)
4. [El número mágico 4096 — anatomía de la memoria CHIP-8](#4-el-número-mágico-4096--anatomía-de-la-memoria-chip-8)
5. [Por qué exactamente 16 registros V](#5-por-qué-exactamente-16-registros-v)
6. [Por qué exactamente 16 niveles de stack](#6-por-qué-exactamente-16-niveles-de-stack)
7. [Por qué exactamente 16 teclas](#7-por-qué-exactamente-16-teclas)
8. [El rol de `0x0F` como máscara de nibble](#8-el-rol-de-0x0f-como-máscara-de-nibble)
9. [El rol de `0xFF` como máscara de byte completo](#9-el-rol-de-0xff-como-máscara-de-byte-completo)
10. [Por qué `memset` con 0 inicializa todo correctamente](#10-por-qué-memset-con-0-inicializa-todo-correctamente)
11. [`assert` vs manejo de errores normal](#11-assert-vs-manejo-de-errores-normal)
12. [El array `keyboard[CHIP8_TOTAL_KEYS]` de booleans](#12-el-array-keyboardchip8_total_keys-de-booleans)
13. [La función `chip8_keyboard_map` — búsqueda lineal intencional](#13-la-función-chip8_keyboard_map--búsqueda-lineal-intencional)
14. [Por qué el stack pointer `SP` es `unsigned char`](#14-por-qué-el-stack-pointer-sp-es-unsigned-char)
15. [La mecánica del push/pop — por qué el orden importa](#15-la-mecánica-del-pushpop--por-qué-el-orden-importa)
16. [Include guards — `#ifndef / #define / #endif`](#16-include-guards--ifndef--define--endif)
17. [Forward declaration `struct chip8;` en chip8stack.h](#17-forward-declaration-struct-chip8-en-chip8stackh)
18. [La variable `keyboard_map` en main.c — por qué es `const`](#18-la-variable-keyboard_map-en-mainc--por-qué-es-const)
19. [El cast `(char)key` en chip8_keyboard_map](#19-el-cast-charkey-en-chip8_keyboard_map)
20. [El `goto out` — control de flujo no estructurado](#20-el-goto-out--control-de-flujo-no-estructurado)
21. [SDL_RenderClear con color `(0, 0, 0, 0)` — el canal alpha](#21-sdl_renderclear-con-color-0-0-0-0--el-canal-alpha)
22. [El multiplier de ventana — `CHIP8_WINDOW_MULTIPLIER`](#22-el-multiplier-de-ventana--chip8_window_multiplier)
23. [Compilación separada en el Makefile — por qué `.o` por módulo](#23-compilación-separada-en-el-makefile--por-qué-o-por-módulo)
24. [Por qué `chip8.o` no está en OBJECTS — el bug del Makefile](#24-por-qué-chip8o-no-está-en-objects--el-bug-del-makefile)
25. [Por qué `static` en las funciones de validación](#25-por-qué-static-en-las-funciones-de-validación)
26. [El futuro: cómo las máscaras de bits decodifican opcodes](#26-el-futuro-cómo-las-máscaras-de-bits-decodifican-opcodes)

---

## 1. El Sistema Hexadecimal y Por Qué Domina la Emulación

Antes de entrar a las máscaras (`0x0F`, `0xFF`), hay que entender *por qué* la emulación vive en hexadecimal.

La razón es simple: **un byte son exactamente 2 dígitos hexadecimales**.

```
Un byte tiene 8 bits:
┌──┬──┬──┬──┬──┬──┬──┬──┐
│ 7│ 6│ 5│ 4│ 3│ 2│ 1│ 0│  ← posición del bit
└──┴──┴──┴──┴──┴──┴──┴──┘
└──────────┘└──────────┘
  nibble alto  nibble bajo
  (bits 7-4)   (bits 3-0)
```

Cada grupo de 4 bits se llama **nibble** y puede representar exactamente los valores `0-15`, es decir, un dígito hexadecimal (`0-F`). Por eso:

| Representación | Ejemplo    |
|----------------|------------|
| Decimal        | `255`      |
| Binario        | `11111111` |
| Hexadecimal    | `0xFF`     |

En CHIP-8, **las instrucciones son de 2 bytes (16 bits)** y cada nibble dentro de esos 16 bits tiene un significado específico. Por ejemplo, la instrucción `0x6XNN`:
- `6` → opcode "cargar valor inmediato"
- `X` → índice del registro destino (0x0–0xF = registros V0–VF)
- `NN` → valor de 8 bits a cargar

Esta es la razón por la que todo en un emulador de CHIP-8 se expresa en hexadecimal — es la forma natural de "ver" los nibbles.

---

## 2. Por Qué `unsigned char` y no `int` — la Guerra de Tipos

En `chip8memory.h`:
```c
struct chip8_memory {
    unsigned char memory[CHIP8_MEMORY_SIZE];
};
```

En `chip8registers.h`:
```c
unsigned char V[CHIP8_TOTAL_DATA_REGISTERS];
unsigned char delay_timer;
unsigned char sound_timer;
unsigned char SP;
```

### ¿Por qué `unsigned char` y no solo `int`?

**Razón 1: Tamaño exacto de 8 bits**

En C, `int` tiene un tamaño mínimo de 16 bits y en la mayoría de plataformas modernas son 32 bits. Si usaras `int` para la memoria:

```c
// MAL — cada "byte" ocuparía 4 bytes en la mayoría de sistemas
int memory[4096];  // ocuparía 4096 * 4 = 16,384 bytes en RAM, no 4,096

// BIEN — cada elemento ocupa exactamente 1 byte
unsigned char memory[4096];  // ocupa exactamente 4,096 bytes
```

**Razón 2: El "unsigned" no es decorativo**

`char` puede ser `signed` o `unsigned` dependiendo del compilador y la plataforma (es el único tipo primitivo de C con signo ambiguo). Si fuera `signed char`:
- Rango: `-128` a `127`
- El byte `0xFF` (255 en binario: `11111111`) se interpretaría como `-1`
- Cualquier aritmética con ese byte daría resultados incorrectos

Con `unsigned char`:
- Rango: `0` a `255`
- El byte `0xFF` = `255` → correcto
- La aritmética wrap-around de 8 bits funciona de forma predecible

```c
// Ejemplo de por qué importa el "unsigned":
signed char a = 0xFF;    // a = -1  ← INCORRECTO para emulación
unsigned char b = 0xFF;  // b = 255 ← CORRECTO

// El wrap-around (desbordamiento) también es predecible:
unsigned char x = 255;
x += 1;  // x = 0 (wrap-around modular, como debe ser)
```

**Razón 3: Compatibilidad con la especificación hardware**

El CHIP-8 original operaba con bytes de 8 bits sin signo. Los registros V0–VF almacenaban valores de 0 a 255. Usar `unsigned char` es mapear directamente la especificación al código.

---

## 3. Por Qué `unsigned short` para PC, I y el Stack

```c
unsigned short I;
unsigned short PC;
// y en chip8stack.h:
unsigned short stack[CHIP8_TOTAL_STACK_DEPTH];
```

### ¿Por qué `unsigned short` y no `unsigned char`?

Porque estos valores necesitan representar **direcciones de memoria** que van de `0x000` a `0xFFF` (0 a 4095).

Un `unsigned char` solo puede almacenar valores de 0 a 255. La dirección `0x200` = 512, que ya no cabe en 8 bits.

```
¿Cuántos bits necesitamos para representar 4096?
4096 = 2^12 → necesitamos al menos 12 bits

unsigned char  → 8 bits  → máximo 255  ← insuficiente
unsigned short → 16 bits → máximo 65535 ← suficiente (y estándar)
```

`unsigned short` garantiza al menos 16 bits en todas las plataformas C, dando un rango de 0 a 65,535 — más que suficiente para la memoria de 4 KB del CHIP-8.

### ¿Por qué el stack también es `unsigned short`?

```c
unsigned short stack[CHIP8_TOTAL_STACK_DEPTH];
```

El stack almacena **direcciones de retorno**. Cuando el CHIP-8 ejecuta `CALL addr`, guarda en el stack la dirección de la siguiente instrucción para poder hacer `RET` después. Esas direcciones son de 12 bits (espacio de direccionamiento del CHIP-8), que no caben en 8 bits pero sí en 16. Por eso `unsigned short`.

---

## 4. El Número Mágico 4096 — Anatomía de la Memoria CHIP-8

```c
#define CHIP8_MEMORY_SIZE 4096
```

### ¿Por qué exactamente 4096 bytes?

No es un número arbitrario. Es `2^12` = `0x1000` en hexadecimal.

El CHIP-8 usa un **espacio de direcciones de 12 bits** para sus instrucciones. El mayor número de 12 bits es:
```
0xFFF = 1111 1111 1111 en binario = 4095 en decimal
```

Eso significa que el CHIP-8 puede direccionar posiciones de memoria desde `0x000` hasta `0xFFF`, lo cual son exactamente **4096 posiciones** (4096 = 0xFFF + 1).

### Mapa de memoria del CHIP-8

La memoria no es un espacio uniforme — tiene zonas con propósito específico:

```
┌─────────────────────────────────────┐  0x000
│  Zona reservada del intérprete      │
│  (0x000 – 0x1FF = primeros 512 B)   │
│  ← Aquí se cargan los sprites de   │
│     los dígitos hexadecimales (0-F) │
├─────────────────────────────────────┤  0x200
│                                     │
│  Zona de programas (ROMs)           │
│  (0x200 – 0xFFF = 3584 bytes)       │
│  ← Aquí se carga la ROM del juego  │
│  ← El PC inicia aquí (0x200)        │
│                                     │
└─────────────────────────────────────┘  0xFFF
```

> **¿Por qué 0x200?** En las computadoras originales (COSMAC VIP), los primeros 512 bytes (`0x000–0x1FF`) eran ocupados por el intérprete CHIP-8 mismo, cargado en RAM. Las ROMs de los juegos siempre empezaban en `0x200` para no sobreescribir el intérprete. Esta convención se mantiene en los emuladores modernos por compatibilidad.

---

## 5. Por Qué Exactamente 16 Registros V

```c
#define CHIP8_TOTAL_DATA_REGISTERS 16
unsigned char V[CHIP8_TOTAL_DATA_REGISTERS];
```

### La razón: el nibble de dirección de registro

En el formato de instrucciones del CHIP-8, el campo que indica **qué registro usar** tiene exactamente **4 bits** (un nibble):

```
Instrucción de 16 bits:  0x8XY1
                              │└─ 4 bits para Y (registro fuente)
                              └── 4 bits para X (registro destino)
```

Con 4 bits puedes representar exactamente `2^4 = 16` valores distintos (`0x0` a `0xF`). Por eso existen exactamente 16 registros: V0, V1, ..., V9, VA, VB, VC, VD, VE, **VF**.

```c
// El registro VF (índice 15 = 0xF) es especial:
// Se usa como FLAG de carry, borrow y colisión de sprites.
// Por convenio, los programas no deben usarlo como dato general.
V[0xF] = 1;  // carry flag activado
V[0xF] = 0;  // carry flag desactivado
```

El array `V[16]` permite indexarlo directamente con el nibble extraído de la instrucción:
```c
// Pseudocódigo de decodificación:
uint16_t opcode = fetch();
uint8_t x = (opcode & 0x0F00) >> 8;  // nibble X → índice de registro
uint8_t y = (opcode & 0x00F0) >> 4;  // nibble Y → índice de registro
chip8->registers.V[x] += chip8->registers.V[y];  // indexado directo ✓
```

---

## 6. Por Qué Exactamente 16 Niveles de Stack

```c
#define CHIP8_TOTAL_STACK_DEPTH 16
unsigned short stack[CHIP8_TOTAL_STACK_DEPTH];
```

### El origen: la especificación original

La especificación original del CHIP-8 no definía explícitamente la profundidad del stack — era un detalle del hardware. La implementación en COSMAC VIP soportaba 12 niveles de anidación. La mayoría de emuladores modernos usa **16** por convención establecida en la referencia de Cowgod (la biblia del CHIP-8).

### ¿Qué significa "16 niveles"?

Significa que puedes tener como máximo **16 llamadas a subrutinas anidadas**:

```
main_program → subroutine_A → subroutine_B → subroutine_C → ... (máx. 16 niveles)
```

Cada nivel usa un slot del stack para guardar la dirección de retorno. Si intentas anidar más de 16, el emulador hace `assert(SP < 16)` y se detiene.

```
Stack antes de ninguna llamada:
SP = 0
stack: [  ][  ][  ]...[  ]

Después de CALL 0x300:
SP = 1
stack: [0x202][  ][  ]...[  ]
         ↑ dirección de retorno

Después de otro CALL 0x500 desde dentro de 0x300:
SP = 2
stack: [0x202][0x302][  ]...[  ]

RET desde 0x500:
SP = 1
stack: [0x202][0x302][  ]...[  ]  ← El valor 0x302 todavía está
PC = 0x302  ← pero ya no importa, SP apunta por debajo
```

---

## 7. Por Qué Exactamente 16 Teclas

```c
#define CHIP8_TOTAL_KEYS 16
bool keyboard[CHIP8_TOTAL_KEYS];
```

### La razón histórica

El CHIP-8 fue diseñado para el **COSMAC VIP**, que tenía un teclado hexadecimal físico de 16 teclas: los dígitos `0-9` y las letras `A-F`. Era un teclado de 4×4:

```
┌───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ C │
├───┼───┼───┼───┤
│ 4 │ 5 │ 6 │ D │
├───┼───┼───┼───┤
│ 7 │ 8 │ 9 │ E │
├───┼───┼───┼───┤
│ A │ 0 │ B │ F │
└───┴───┴───┴───┘
```

Cada tecla corresponde a un nibble (4 bits). Las instrucciones del CHIP-8 que leen el teclado usan un nibble para especificar qué tecla checar:
```
Instrucción EX9E: "salta si la tecla con valor X está presionada"
                   X es un nibble → valores 0x0 a 0xF → 16 teclas posibles
```

### El array de booleans

```c
bool keyboard[16];
// keyboard[0x0] → tecla '0'
// keyboard[0xA] → tecla 'A'
// keyboard[0xF] → tecla 'F'
```

Este diseño es elegante: el **índice** del array **es** el código de tecla CHIP-8. No hace falta ninguna estructura de datos adicional — solo indexas directamente con el valor extraído de la instrucción.

```c
// Si la instrucción dice "checa la tecla 0xA":
uint8_t key = 0xA;
if (chip8_keyboard_is_down(&chip8->keyboard, key)) {
    // la tecla A está presionada
}
// Esto se reduce a: return keyboard->keyboard[0xA];
// Acceso directo en O(1)
```

---

## 8. El Rol de `0x0F` Como Máscara de Nibble

> **Nota:** Aunque `0x0F` no aparece explícitamente en el código actual, **aparecerá obligatoriamente** cuando se implemente el ciclo de fetch-decode-execute de la CPU. Esta sección explica el concepto que es fundamental para entender la decodificación de opcodes.

### ¿Qué es una máscara de bits?

Una máscara de bits es un valor que, al aplicar la operación AND bit a bit (`&`), "apaga" (pone a 0) todos los bits que no nos interesan, dejando solo los que queremos leer.

```
Valor:   1010 1111  (0xAF)
Máscara: 0000 1111  (0x0F)  ← "máscara de nibble bajo"
         ─────────── AND
Resultado:0000 1111 (0x0F)  ← solo el nibble bajo queda
```

### `0x0F` = `0000 1111` — extrae el nibble bajo

`0x0F` tiene los 4 bits bajos en 1 y los 4 bits altos en 0:
```
0x0F en binario: 0000 1111
                 ││││ ││││
                 │││└─┘│││── bit 0
                 │││   ││└── bit 1
                 │││   │└─── bit 2
                 │││   └──── bit 3  ← los 4 bits bajos (nibble bajo)
                 ││└──────── bit 4
                 │└───────── bit 5
                 └────────── bit 6 y 7 (todos en 0)
```

### Uso en decodificación de opcodes CHIP-8

Un opcode CHIP-8 de 16 bits tiene 4 nibbles. Para extraer cada uno:

```c
uint16_t opcode = 0x8XY1;  // ejemplo: instrucción "V[X] |= V[Y]"

// Extraer el nibble más alto (bits 15-12): tipo de instrucción
uint8_t tipo = (opcode & 0xF000) >> 12;  // tipo = 0x8

// Extraer el nibble X (bits 11-8): primer registro
uint8_t x    = (opcode & 0x0F00) >> 8;   // x = X

// Extraer el nibble Y (bits 7-4): segundo registro
uint8_t y    = (opcode & 0x00F0) >> 4;   // y = Y

// Extraer el nibble bajo (bits 3-0): subtipo de operación
uint8_t n    = (opcode & 0x000F);        // n = 1  ← aquí aparece 0x0F (conceptualmente)
```

Nota que `0x000F` es equivalente a `0x0F` cuando se aplica sobre los 4 bits menos significativos de un valor de 16 bits. **La máscara `0x0F` en contexto de 8 bits** se usa para extraer el nibble bajo de un byte:

```c
uint8_t byte = 0xAB;
uint8_t nibble_bajo = byte & 0x0F;  // 0x0B = solo los 4 bits bajos
uint8_t nibble_alto = (byte >> 4);  // 0x0A = los 4 bits altos desplazados
```

Esta técnica se usará intensamente al implementar opcodes como:
- `0xFX33` (BCD decode): extrae los dígitos individuales de un número
- `0x8XYN`: el nibble N determina qué operación ALU hacer
- `0xDXYN`: el nibble N es la altura del sprite a dibujar

---

## 9. El Rol de `0xFF` Como Máscara de Byte Completo

### `0xFF` = `1111 1111` — 8 bits todos en 1

```
0xFF en binario: 1111 1111
```

Tiene dos usos principales en emulación de CHIP-8:

### Uso 1: Truncar a 8 bits (wrap-around)

Cuando realizas operaciones aritméticas con `unsigned char`, C *promueve* internamente los operandos a `int` (32 bits) para el cálculo. El resultado puede ser mayor de 255. Para "forzar" que el resultado sea de 8 bits:

```c
unsigned char a = 200;
unsigned char b = 100;
// a + b = 300, que es mayor a 255 (no cabe en 8 bits)

// Sin máscara — pero como es unsigned char, ya hay truncación automática:
unsigned char resultado = a + b;  // = 44 (300 % 256 = 44) ← automático

// Con máscara explícita — deja el intento claro en el código:
int resultado_int = (int)a + (int)b;  // = 300
unsigned char resultado_byte = resultado_int & 0xFF;  // = 44

// Son equivalentes, pero & 0xFF es más explícito en la intención
```

### Uso 2: Extraer el byte bajo de un valor de 16 bits

Cuando guardas en memoria una instrucción de 16 bits (como la dirección de retorno en el stack), necesitas poder extraer byte alto y byte bajo:

```c
uint16_t opcode = 0xABCD;

uint8_t byte_bajo  = opcode & 0x00FF;        // 0xCD
uint8_t byte_alto  = (opcode >> 8) & 0xFF;   // 0xAB

// Reconstruir:
uint16_t reconstruido = ((uint16_t)byte_alto << 8) | byte_bajo;  // = 0xABCD
```

La máscara `& 0xFF` después del shift garantiza que aunque `opcode >> 8` pueda retener basura en bits superiores (en sistemas donde el shift es signed), solo nos quedamos con los 8 bits que importan.

### Uso 3: El carry flag en operaciones aritméticas

```c
// Instrucción CHIP-8 0x8XY4: V[X] += V[Y], VF = carry
uint16_t resultado = V[X] + V[Y];

// ¿Hubo carry? Si el resultado supera 8 bits:
V[0xF] = (resultado > 0xFF) ? 1 : 0;  // ← 0xFF = 255 = límite de 8 bits

// Truncar a 8 bits:
V[X] = resultado & 0xFF;  // solo los 8 bits bajos
```

---

## 10. Por Qué `memset` con 0 Inicializa Todo Correctamente

```c
void chip8_init(struct chip8* chip8) {
    memset(chip8, 0, sizeof(struct chip8));
}
```

### ¿Qué hace `memset` exactamente?

`memset(ptr, value, size)` escribe el byte `value` en cada una de las `size` posiciones de memoria a partir de `ptr`.

```c
memset(chip8, 0, sizeof(struct chip8));
// Escribe el byte 0x00 en CADA BYTE de la estructura chip8
```

### ¿Por qué funciona para todos los tipos de miembros?

Esto funciona porque el estándar C garantiza que **cero en bits es cero para todos los tipos aritméticos**:

| Tipo | Representación de 0 | Todos los bits en 0 |
|------|---------------------|---------------------|
| `unsigned char` | `0x00` | ✅ sí |
| `unsigned short` | `0x0000` | ✅ sí |
| `int` | `0x00000000` | ✅ sí |
| `bool` | `false` | ✅ sí |
| `float` | `0.0f` | ✅ sí (IEEE 754) |
| puntero | `NULL` | ✅ en casi todos los sistemas |

Por eso poner todos los bytes a 0 con `memset` equivale a:
```c
chip8->memory   → todos los 4096 bytes de RAM en 0x00
chip8->registers.V[0..15] → todos los registros en 0
chip8->registers.I  → 0
chip8->registers.PC → 0  (¡ojo! luego habrá que inicializarlo a 0x200)
chip8->registers.SP → 0
chip8->registers.delay_timer → 0
chip8->registers.sound_timer → 0
chip8->stack.stack[0..15] → todos los slots en 0
chip8->keyboard.keyboard[0..15] → todas las teclas en false
```

### ¿Y por qué no usar un inicializador `= {0}`?

El código en `main.c` hace:
```c
struct chip8 chip8 = {0};
chip8_init(&chip8);
```

La inicialización `= {0}` ya pone todo a cero. Luego `chip8_init` llama a `memset` que... también pone todo a cero. ¿Redundante? Sí, actualmente. Pero `chip8_init` está pensada para el futuro cuando deba cargar también el **font set** (los sprites de los dígitos 0–F) en `0x000–0x04F`. En ese punto, `memset` limpia primero y luego se cargan los datos del font.

---

## 11. `assert` vs Manejo de Errores Normal

```c
static void chip8_is_memory_in_bounds(int index) {
    assert(index >= 0 && index < CHIP8_MEMORY_SIZE);
}

static void chip8_stack_in_bounds(struct chip8 *chip8) {
    assert(chip8->registers.SP < CHIP8_TOTAL_STACK_DEPTH);
}
```

### ¿Por qué `assert` y no `if (error) return -1`?

`assert` es una herramienta de **desarrollo**, no de manejo de errores en producción. La distinción es importante:

| Criterio | `assert` | `if/return error` |
|---|---|---|
| ¿Cuándo dispara? | Solo en builds de debug | Siempre |
| ¿Qué hace al fallar? | Termina el programa abruptamente | Retorna un código de error |
| Rendimiento | Zero overhead en release | Overhead en cada llamada |
| ¿Para qué sirve? | Invariantes que NUNCA deben fallar | Errores externos esperados |

Un acceso fuera de memoria en un emulador es una **violación de invariante**, no un error recoverable. Si el PC apunta a `0x1001` (fuera del espacio de 4 KB), hay un bug en la decodificación del opcode — no tiene sentido "continuar" y corromper memoria.

```c
// assert se desactiva con NDEBUG (en builds de release):
#define NDEBUG
#include <assert.h>
assert(false);  // ← esta línea se convierte en NADA con NDEBUG

// Para builds de debug (como en este proyecto con -g):
// assert(false) → imprime mensaje de error + archivo + línea + termina
```

El flag `-g` en el Makefile compila con información de debug, lo que hace que los mensajes de `assert` sean más informativos.

---

## 12. El Array `keyboard[CHIP8_TOTAL_KEYS]` de Booleans

```c
struct chip8_keyboard {
    bool keyboard[CHIP8_TOTAL_KEYS];  // bool keyboard[16]
};
```

### ¿Por qué `bool` y no `int` o `unsigned char`?

Tres razones:

**Razón 1: Semántica clara**

`bool` expresa la intención: el estado de una tecla es binario — presionada o no presionada. `int` podría implicar que hay más de dos estados posibles.

**Razón 2: Las instrucciones CHIP-8 de teclado son booleanas**

```
EX9E: salta si la tecla V[X] está PRESIONADA
EXA1: salta si la tecla V[X] NO está presionada
FX0A: espera hasta que CUALQUIER tecla sea presionada
```

Todas las operaciones de teclado son booleanas — no hay "cuánto está presionada" (analógico), solo "está o no está".

**Razón 3: `sizeof(bool)` es típicamente 1 byte**

Aunque lógicamente es 1 bit, en C `bool` se almacena en 1 byte para eficiencia de acceso. El array de 16 bools ocupa 16 bytes, igual que 16 `unsigned char`.

### Cómo funciona el indexado

```c
void chip8_keyboard_down(struct chip8_keyboard *keyboard, int key) {
    keyboard->keyboard[key] = true;
    // key es el índice CHIP-8 (0x0 a 0xF)
    // keyboard->keyboard[0xA] = true → tecla 'A' presionada
}

bool chip8_keyboard_is_down(struct chip8_keyboard *keyboard, int key) {
    return keyboard->keyboard[key];
    // Si keyboard->keyboard[0xA] == true → tecla 'A' está presionada
}
```

El array es el "estado completo del teclado" en un único bloque de 16 bytes, directamente indexable por el código de tecla CHIP-8.

---

## 13. La Función `chip8_keyboard_map` — Búsqueda Lineal Intencional

```c
int chip8_keyboard_map(const unsigned char *map, unsigned char key) {
    for (int i = 0; i < CHIP8_TOTAL_KEYS; i++) {
        if (map[i] == key) {
            return i;
        }
    }
    return -1;
}
```

### ¿Por qué una búsqueda lineal y no un hash map o array inverso?

**Razón 1: El tamaño es fijo y pequeño (16 elementos)**

La búsqueda lineal en un array de 16 elementos es **prácticamente O(1)** en términos de tiempo real. El loop completo tarda nanosegundos. La complejidad teórica O(n) no importa cuando n=16.

**Razón 2: El retorno de `-1` como "no encontrado"**

El tipo de retorno es `int` (con signo), no `unsigned char`. Esto permite retornar `-1` como valor centinela que indica "esta tecla no está en el mapa CHIP-8". Ningún índice válido puede ser negativo.

```c
int vkey = chip8_keyboard_map(keyboard_map, (char)key);
if (vkey != -1) {
    // tecla válida del CHIP-8
    chip8_keyboard_down(&chip8.keyboard, vkey);
}
// Si es -1, la tecla presionada (e.g., Shift, Control) no es parte del CHIP-8
```

**Razón 3: Flexibilidad del mapa**

El mapa `keyboard_map` es un parámetro — no está hardcodeado. Esto permite que el mismo `chip8_keyboard_map` funcione con cualquier tabla de mapeo:

```c
// Mapa QWERTY (el usado en main.c):
const unsigned char keyboard_map[] = {
    SDLK_0, SDLK_1, SDLK_2, SDLK_3, SDLK_4, SDLK_5,
    SDLK_6, SDLK_7, SDLK_8, SDLK_9, SDLK_A, SDLK_B,
    SDLK_C, SDLK_D, SDLK_E, SDLK_F
};

// Podría haber un mapa alternativo para un layout diferente:
const unsigned char keyboard_map_alt[] = {
    SDLK_x, SDLK_1, SDLK_2, SDLK_3,  // tecla CHIP-8 0 → X física
    SDLK_q, SDLK_w, SDLK_e, SDLK_a,  // tecla CHIP-8 4 → Q física
    // ...
};
```

El mismo `chip8_keyboard_map` funciona para ambos.

---

## 14. Por Qué el Stack Pointer `SP` es `unsigned char`

```c
unsigned char SP;  // en chip8registers.h
```

### ¿Por qué no `int` o `unsigned short`?

`SP` es un índice en el array `stack[16]`. Sus valores válidos son solo `0` a `16` (o más precisamente, `0` a `CHIP8_TOTAL_STACK_DEPTH`). Eso cabe perfectamente en 8 bits (`unsigned char` va de 0 a 255).

```
SP válidos:
0  → stack vacío, siguiente push irá a stack[0]
1  → hay 1 elemento, en stack[0]; próximo push irá a stack[1]
...
16 → stack lleno, próximo push dispararía assert
```

Pero hay una trampa: **SP es `unsigned char`** y en `chip8_stack_pop`:

```c
unsigned short chip8_stack_pop(struct chip8* chip8) {
    chip8->registers.SP -= 1;  // ← ¿Qué pasa si SP es 0?
    chip8_stack_in_bounds(chip8);
    return chip8->stack.stack[chip8->registers.SP];
}
```

Si `SP` es `unsigned char` y vale `0`, hacer `SP -= 1` resulta en **underflow** (la aritmética sin signo en C da wrap-around):

```
0 - 1 = 255 en unsigned char (wrap-around modular)
```

Luego `chip8_stack_in_bounds` haría `assert(255 < 16)` → ¡falla! Así que el assert actúa como salvaguarda contra el underflow también. Diseño correcto.

---

## 15. La Mecánica del Push/Pop — Por Qué el Orden Importa

```c
void chip8_stack_push(struct chip8* chip8, unsigned short val) {
    chip8_stack_in_bounds(chip8);                        // 1. Verificar bounds ANTES
    chip8->stack.stack[chip8->registers.SP] = val;       // 2. Escribir en SP actual
    chip8->registers.SP += 1;                            // 3. Incrementar SP
}

unsigned short chip8_stack_pop(struct chip8* chip8) {
    chip8->registers.SP -= 1;                            // 1. Decrementar SP PRIMERO
    chip8_stack_in_bounds(chip8);                        // 2. Verificar bounds DESPUÉS
    unsigned short val = chip8->stack.stack[chip8->registers.SP];  // 3. Leer
    return val;
}
```

### Visualización del estado de la pila

Este es un **stack creciente hacia arriba** donde SP apunta a la **próxima posición libre**:

```
PUSH de 0x202:
Antes:  SP=0  [  ][  ][  ]...
                ↑ SP apunta aquí (posición libre)

        Escribe 0x202 en stack[0]
        SP += 1

Después: SP=1 [0x202][  ][  ]...
                      ↑ SP apunta aquí (nueva posición libre)

PUSH de 0x400:
Después: SP=2 [0x202][0x400][  ]...
                             ↑ SP apunta aquí

POP:
        SP -= 1  → SP=1
        Lee stack[1] = 0x400
Después: SP=1 [0x202][0x400][  ]...
                      ↑ SP (el dato 0x400 sigue ahí pero SP ya no lo ve)
```

### ¿Por qué verificar bounds antes del push pero después del decremento en pop?

**Push**: Antes de escribir, verificamos que `SP < 16`. Si `SP == 16`, el stack está lleno y escribir en `stack[16]` sería buffer overflow.

**Pop**: Primero decrementamos SP (porque SP apunta a la posición *siguiente libre*, no al tope actual). Luego verificamos que el nuevo SP no sea negativo/underflow. Si SP era 0 y decrementamos a 255 (wrap), el assert lo captura.

---

## 16. Include Guards — `#ifndef / #define / #endif`

Todos los headers tienen este patrón:

```c
// chip8memory.h
#ifndef CHIP8MEMORY_H
#define CHIP8MEMORY_H

// ... contenido del header ...

#endif
```

### ¿Por qué son necesarios?

El problema que resuelven: **la inclusión múltiple**.

```c
// chip8.h incluye:
#include "chip8memory.h"
#include "chip8stack.h"  // chip8stack.h también incluye chip8.h...

// Si no hubiera guards, el preprocesador expandiría:
// chip8memory.h → contenido completo
// chip8memory.h → ERROR: redefinición de struct chip8_memory
```

### Cómo funcionan los guards

```
Primera vez que el compilador ve #include "chip8memory.h":
1. ¿Está definido CHIP8MEMORY_H? → NO
2. Ejecuta: #define CHIP8MEMORY_H (ahora está definido)
3. Procesa el contenido del header

Segunda vez que el compilador ve #include "chip8memory.h":
1. ¿Está definido CHIP8MEMORY_H? → SÍ
2. Salta todo hasta #endif
3. No procesa nada → no hay redefinición
```

### La convención del nombre del guard

El nombre del macro guard (`CHIP8MEMORY_H`, `CHIP8KEYBOARD_H`, etc.) sigue la convención:

```
Nombre del archivo → mayúsculas → puntos reemplazados por _
chip8memory.h → CHIP8MEMORY_H
config.h → CONFIG_H
chip8registers.h → CHIP8REGISTERS_H
```

Aunque el nombre podría ser cualquier cosa, seguir esta convención asegura que sea único para cada archivo.

---

## 17. Forward Declaration `struct chip8;` en chip8stack.h

```c
// chip8stack.h
#ifndef CHIP8STACK_H
#define CHIP8STACK_H
#include "config.h"

struct chip8;  // ← Forward declaration

struct chip8_stack {
    unsigned short stack[CHIP8_TOTAL_STACK_DEPTH];
};

void chip8_stack_push(struct chip8* chip8, unsigned short val);
unsigned short chip8_stack_pop(struct chip8* chip8);
#endif
```

### ¿Qué es una forward declaration y por qué es necesaria?

El problema: `chip8stack.h` necesita referenciar `struct chip8` en las firmas de sus funciones:

```c
void chip8_stack_push(struct chip8* chip8, unsigned short val);
//                     ─────────── ¿qué es esto?
```

Pero `chip8.h` (que define `struct chip8`) incluye a `chip8stack.h` — habría una dependencia circular:

```
chip8.h → #include "chip8stack.h"
chip8stack.h → #include "chip8.h"  ← ¡bucle!
```

La solución es la **forward declaration**: declarar que `struct chip8` existe sin definir su contenido. El compilador sabe que `chip8*` es un puntero a esa estructura y puede calcular el tamaño del puntero (siempre fijo, sin importar el tamaño de la estructura), pero no puede acceder a sus miembros todavía.

```c
struct chip8;  // "existe una estructura llamada chip8"

// Ahora puedes declarar punteros a ella:
void chip8_stack_push(struct chip8* chip8, ...);  // ✓ solo un puntero

// Pero NO puedes hacer esto aún:
// chip8->registers.SP  ← ❌ compilador no conoce los miembros todavía
```

En `chip8stack.c`, sí se incluye `chip8.h` completo, lo que permite acceder a los miembros:

```c
// chip8stack.c
#include "chip8stack.h"
#include "chip8.h"  // ← aquí sí se incluye el header completo

void chip8_stack_push(struct chip8* chip8, unsigned short val) {
    chip8->registers.SP += 1;  // ✓ ahora el compilador conoce la estructura
}
```

---

## 18. La Variable `keyboard_map` en main.c — Por Qué es `const`

```c
const unsigned char keyboard_map[CHIP8_TOTAL_KEYS] = {
    SDLK_0, SDLK_1, SDLK_2, SDLK_3, SDLK_4, SDLK_5,
    SDLK_6, SDLK_7, SDLK_8, SDLK_9, SDLK_A, SDLK_B,
    SDLK_C, SDLK_D, SDLK_E, SDLK_F
};
```

### `const` — no es solo documentación

El calificador `const` hace que el compilador:
1. **Rechace modificaciones** al array (error de compilación si intentas `keyboard_map[0] = X`)
2. **Pueda almacenarlo** en memoria de solo lectura (sección `.rodata` del ejecutable)
3. **Genere código más eficiente** porque sabe que los valores no cambiarán

### Por qué el parámetro de `chip8_keyboard_map` también es `const`

```c
int chip8_keyboard_map(const unsigned char *map, unsigned char key);
//                     ─────
```

La firma acepta un `const unsigned char*` porque:
- El contrato de la función es "solo leer el mapa, no modificarlo"
- Permite pasar tanto punteros a `const` como punteros a no-`const`
- Si fuera `unsigned char*` (sin const), no podrías pasar `keyboard_map` sin un cast

### ¿Por qué `unsigned char` y no los SDL keycodes directamente?

Los `SDLK_*` constantes de SDL3 son de tipo `SDL_Keycode`, que puede ser un `int` de 32 bits o más. Pero los valores ASCII de las teclas 0-9 y A-F están en el rango 0–127, que cabe en un `unsigned char`.

> ⚠️ **Nota de compatibilidad**: En SDL3 los `SDLK_*` pueden ser valores grandes (SDL_Keycode usa `uint32_t` internamente). Almacenarlos en `unsigned char` trunca el valor. Para las teclas alfanuméricas básicas (`0-9`, `A-F`) esto funciona porque sus keycodes coinciden con los valores ASCII, que son < 128. Pero para teclas especiales, este enfoque puede fallar.

---

## 19. El Cast `(char)key` en chip8_keyboard_map

```c
case SDL_EVENT_KEY_DOWN: {
    SDL_Keycode key = event.key.key;
    int vkey = chip8_keyboard_map(keyboard_map, (char)key);
    //                                          ─────────
```

### ¿Por qué `(char)key` y no `(unsigned char)key`?

`SDL_Keycode` es típicamente `int32_t` o `uint32_t`. La firma de `chip8_keyboard_map` acepta `unsigned char`. El cast `(char)key` trunca el keycode a 8 bits.

Para las teclas `SDLK_0` = `0x30`, `SDLK_A` = `0x61`, etc. (valores ASCII), el truncamiento a 8 bits es seguro porque todos están en el rango 0–127. El cast funciona correctamente para el mapeo implementado.

Sin embargo, hay un potencial issue: `(char)` puede ser signed en algunas plataformas, mientras que el parámetro de la función es `unsigned char`. El compilador hace una conversión implícita adicional. Para código más correcto y explícito:

```c
// Más correcto:
int vkey = chip8_keyboard_map(keyboard_map, (unsigned char)key);
```

---

## 20. El `goto out` — Control de Flujo No Estructurado

```c
while (1) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_EVENT_QUIT:
                goto out;  // ← salto fuera de múltiples niveles de anidación
            break;
        }
    }
    // ... renderizado ...
}

out:  // ← etiqueta destino del goto
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
```

### ¿Por qué `goto` y no `break` o una variable de control?

El problema es la **anidación múltiple**: el evento de quit ocurre dentro de:
1. Un `while(1)` externo
2. Un `while(SDL_PollEvent)` interno
3. Un `switch`

`break` en C solo rompe el bloque más cercano — desde el `switch`, `break` saldría del switch, no del loop externo. Para salir de múltiples niveles con `break`, necesitarías:

```c
// Alternativa sin goto — más verbosa:
bool running = true;
while (running) {
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_EVENT_QUIT:
                running = false;  // cambiar flag
                break;  // sale del switch
        }
        if (!running) break;  // sale del while interno
    }
    if (!running) break;  // sale del while externo
}
// código de limpieza aquí
```

Con `goto`, el código es **más legible** porque expresa directamente la intención: "cuando el usuario cierra la ventana, ve a la limpieza".

El `goto` hacia adelante (forward goto) a una etiqueta de limpieza es un patrón aceptado en C del kernel de Linux y otras bases de código C profesionales, especialmente cuando hay recursos que liberar.

---

## 21. SDL_RenderClear con Color `(0, 0, 0, 0)` — El Canal Alpha

```c
SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
SDL_RenderClear(renderer);
```

### Los 4 parámetros: R, G, B, A

```c
SDL_SetRenderDrawColor(renderer, R, G, B, A);
//                               │  │  │  └── Alpha (transparencia): 0=transparente, 255=opaco
//                               │  │  └───── Azul:   0=sin azul,  255=azul máximo
//                               │  └──────── Verde:  0=sin verde, 255=verde máximo
//                               └─────────── Rojo:   0=sin rojo,  255=rojo máximo
```

Para limpiar la pantalla en negro, R=0, G=0, B=0 es correcto.

El último `0` (Alpha=0) en `SDL_RenderClear` es técnicamente irrelevante para la operación de clear cuando se renderiza sobre una ventana opaca, pero **en SDL3** el Alpha del clear color puede importar en renderers con compositing o cuando se renderiza a texturas con canal alpha. Con `A=0` el clear sería "negro completamente transparente".

```c
// Más idiomático para limpiar con negro opaco:
SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);  // A=255 = opaco
SDL_RenderClear(renderer);
```

Para el rectángulo blanco de prueba:
```c
SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0);
//                                              └── también tiene A=0
// R=255, G=255, B=255 = blanco
// Pero A=0 = transparente — puede dar resultados inesperados dependiendo del blending mode
```

---

## 22. El Multiplier de Ventana — `CHIP8_WINDOW_MULTIPLIER`

```c
#define CHIP8_WINDOW_MULTIPLIER 10

SDL_Window *window = SDL_CreateWindow(
    EMULATOR_WINDOW_TITLE,
    CHIP8_WIDTH * CHIP8_WINDOW_MULTIPLIER,   // 64 * 10 = 640 px
    CHIP8_HEIGHT * CHIP8_WINDOW_MULTIPLIER,  // 32 * 10 = 320 px
    0
);
```

### ¿Por qué es necesario?

La resolución nativa del CHIP-8 es **64×32 píxeles**. En un monitor moderno de 1920×1080, una ventana de 64×32 sería prácticamente invisible (menos del 4% del ancho de la pantalla).

El factor ×10 escala:
- `64px × 10 = 640px` de ancho → visible y usable
- `32px × 10 = 320px` de alto → proporcional

Cada "pixel" del CHIP-8 se convierte en un bloque de 10×10 píxeles físicos.

### Por qué definirlo como constante y no hardcodear `640, 320`

```c
// MAL — números mágicos, difícil de cambiar:
SDL_CreateWindow("Chip8", 640, 320, 0);

// BIEN — si quieres factor ×15 en lugar de ×10, cambias UNA línea:
#define CHIP8_WINDOW_MULTIPLIER 15
// Automáticamente → 64*15=960 x 32*15=480
```

Cuando el emulador implemente el renderizado de sprites, usará el mismo multiplier para escalar cada pixel CHIP-8 al tamaño correcto en la ventana SDL.

---

## 23. Compilación Separada en el Makefile — Por Qué `.o` por Módulo

```makefile
OBJECTS = ./build/chip8memory.o ./build/chip8stack.o ./build/chip8keyboard.o

all: ${OBJECTS}
    $(CC) $(CFLAGS) ./src/main.c ${OBJECTS} -o ./bin/main $(LIBS)

build/chip8memory.o: src/chip8memory.c
    gcc ${FLAGS} ${INCLUDES} ./src/chip8memory.c -c -o ./build/chip8memory.o
```

### ¿Por qué no compilar todo junto con un solo comando?

```bash
# ¿Por qué no simplemente?
gcc -g -I./include src/main.c src/chip8memory.c src/chip8stack.c src/chip8keyboard.c -o bin/main -L./lib -lSDL3
```

Esto funcionaría, pero tiene una desventaja crítica: **si cambias un solo archivo, recompila todo**.

Con compilación separada:
- Modificas `chip8keyboard.c` → solo recompila `chip8keyboard.o` + relinkea
- Los otros `.o` (memory, stack) se reutilizan del build anterior
- En proyectos grandes con decenas de archivos, esto ahorra minutos de compilación

### El flag `-c` — compilar sin linkear

```makefile
gcc -c chip8memory.c -o chip8memory.o
#   ─── compilar solo (producir .o, no ejecutable)
```

El flag `-c` instruye a GCC a:
1. Preprocesar el fuente
2. Compilar a código objeto (`.o`)
3. **No** invocar al linker

El paso de linkeo ocurre en el target `all`, donde todos los `.o` + `main.c` se combinan:

```
chip8memory.o  ──┐
chip8stack.o   ──┼──→ [LINKER] ──→ bin/main
chip8keyboard.o──┘
main.c (directo)
```

### Las variables `CFLAGS` vs `FLAGS`

```makefile
CFLAGS = -g -I./include   # ← usado en el linkeo de main
FLAGS  = -g               # ← usado en compilación de .o
INCLUDES = -I ./include   # ← separado de FLAGS para los .o
```

Hay cierta redundancia: `CFLAGS` ya incluye `-I./include`, pero los targets de `.o` usan `FLAGS` + `INCLUDES` por separado. Esta inconsistencia es un candidato a limpieza futura.

---

## 24. Por Qué `chip8.o` No Está en OBJECTS — El Bug del Makefile

```makefile
OBJECTS = ./build/chip8memory.o ./build/chip8stack.o ./build/chip8keyboard.o
# ← chip8.o NO está aquí

# Pero sí existe la regla:
build/chip8.o: src/chip8.c
    gcc ${FLAGS} ${INCLUDES} ./src/chip8.c -c -o ./build/chip8.o
```

`chip8.c` define la función `chip8_init`:

```c
void chip8_init(struct chip8* chip8) {
    memset(chip8, 0, sizeof(struct chip8));
}
```

`main.c` llama a `chip8_init`:

```c
chip8_init(&chip8);
```

Si `chip8.o` no está en `OBJECTS`, el linker no encuentra la definición de `chip8_init` y debería dar un error de "undefined reference". Que compile es porque GCC puede inlinar o incluir de otra forma, o puede que actualmente esté dando un warning que pasa desapercibido.

### Cómo corregirlo

```makefile
# Opción A: agregar chip8.o a OBJECTS
OBJECTS = ./build/chip8memory.o ./build/chip8stack.o ./build/chip8keyboard.o ./build/chip8.o

# Opción B: compilar chip8.c junto con main.c en el paso de linkeo
all: ${OBJECTS}
    $(CC) $(CFLAGS) ./src/main.c ./src/chip8.c ${OBJECTS} -o ./bin/main $(LIBS)
```

---

## 25. Por Qué `static` en las Funciones de Validación

```c
// chip8memory.c
static void chip8_is_memory_in_bounds(int index) {
    assert(index >= 0 && index < CHIP8_MEMORY_SIZE);
}

// chip8stack.c
static void chip8_stack_in_bounds(struct chip8 *chip8) {
    assert(chip8->registers.SP < CHIP8_TOTAL_STACK_DEPTH);
}
```

### ¿Qué hace `static` en una función a nivel de archivo?

En C, `static` aplicado a una función a nivel de file scope (no dentro de otra función) le da **linkage interno**: la función solo es visible dentro del mismo archivo `.c`. No es exportada en la tabla de símbolos del `.o`.

```
Efectos de static en una función:
┌─────────────────────────────────────────────────────┐
│ Sin static:                                         │
│   chip8_is_memory_in_bounds → visible en todo el   │
│   programa después de linkear                       │
│                                                     │
│ Con static:                                         │
│   chip8_is_memory_in_bounds → solo visible dentro   │
│   de chip8memory.c; otros .o no pueden usarla       │
└─────────────────────────────────────────────────────┘
```

### ¿Por qué es importante?

**Encapsulación**: Son funciones de "implementación interna" — no forman parte de la API pública del módulo. Que sean `static` previene que otros módulos las llamen directamente.

**Evitar conflictos de nombres**: Si `chip8stack.c` también tuviera una función llamada `chip8_is_in_bounds` sin `static`, el linker daría error de símbolo duplicado. Con `static`, cada `.c` puede tener su propia función con el mismo nombre sin conflicto.

**Optimización**: El compilador puede optimizar más agresivamente funciones `static` (e.g., inlinarlas) porque sabe que nadie externo las llama.

---

## 26. El Futuro: Cómo las Máscaras de Bits Decodifican Opcodes

Esta sección anticipa la implementación del CPU fetch-decode-execute, donde todo lo anterior converge.

### Fetch — leer 2 bytes de memoria

```c
// El CHIP-8 almacena instrucciones en big-endian:
// El byte en PC es el byte alto, el byte en PC+1 es el byte bajo
uint16_t opcode = (chip8_memory_get(&chip8->memory, chip8->registers.PC) << 8)
                | chip8_memory_get(&chip8->memory, chip8->registers.PC + 1);
chip8->registers.PC += 2;
```

### Decode — extraer los 4 nibbles

```c
uint8_t tipo = (opcode & 0xF000) >> 12;  // nibble más alto
uint8_t x    = (opcode & 0x0F00) >> 8;   // segundo nibble (← usa 0x0F)
uint8_t y    = (opcode & 0x00F0) >> 4;   // tercer nibble
uint8_t n    = (opcode & 0x000F);        // nibble bajo (← usa 0x0F en contexto 4-bit)
uint8_t kk   = (opcode & 0x00FF);        // byte bajo  (← usa 0xFF)
uint16_t nnn = (opcode & 0x0FFF);        // dirección de 12 bits
```

### Execute — tabla de dispatch

```c
switch (tipo) {
    case 0x0:
        if (opcode == 0x00E0) { /* CLS: limpiar pantalla */ }
        if (opcode == 0x00EE) { /* RET: pop stack, PC = dirección retorno */ }
        break;

    case 0x1:
        chip8->registers.PC = nnn;  // JP addr: saltar a nnn
        break;

    case 0x2:
        chip8_stack_push(chip8, chip8->registers.PC);  // CALL addr
        chip8->registers.PC = nnn;
        break;

    case 0x6:
        chip8->registers.V[x] = kk;  // LD Vx, byte: V[x] = kk (byte bajo)
        break;

    case 0x8:
        switch (n) {  // n = nibble bajo distingue la operación ALU
            case 0x0: chip8->registers.V[x]  = chip8->registers.V[y]; break; // LD
            case 0x1: chip8->registers.V[x] |= chip8->registers.V[y]; break; // OR
            case 0x2: chip8->registers.V[x] &= chip8->registers.V[y]; break; // AND
            case 0x4: {  // ADD con carry
                uint16_t result = chip8->registers.V[x] + chip8->registers.V[y];
                chip8->registers.V[0xF] = (result > 0xFF) ? 1 : 0;  // ← 0xFF como límite
                chip8->registers.V[x] = result & 0xFF;               // ← 0xFF como máscara
            } break;
        }
        break;
}
```

Aquí se puede ver cómo cada decisión previa encaja:
- `V[x]` es `unsigned char` → los 8 bits de un registro
- `0xFF` marca el límite de 8 bits para detectar carry
- `0xFF` como máscara trunca el resultado a 8 bits
- `0x0F` (via nibble `n`) selecciona qué operación ALU ejecutar
- `chip8_stack_push/pop` ya implementados funcionan directamente
- `chip8_keyboard_is_down` comprobará teclas con índice directo

---

## Resumen Visual de Todos los "Por Qués"

```
┌─────────────────────────────────────────────────────────────┐
│                   Decisiones de Diseño                      │
├──────────────────────────┬──────────────────────────────────┤
│ unsigned char memory[]   │ 1 byte exacto, sin signo, 0-255  │
│ unsigned short PC/I      │ necesitan > 255 (hasta 4095)     │
│ 4096 bytes               │ 2^12 = espacio de 12 bits        │
│ 16 registros V           │ nibble de 4 bits = 16 valores    │
│ 16 niveles de stack      │ spec + convención Cowgod         │
│ 16 teclas                │ nibble de 4 bits = hex 0-F       │
│ 0x0F                     │ máscara de nibble (4 bits)       │
│ 0xFF                     │ máscara de byte (8 bits)         │
│ memset con 0             │ todos los tipos tienen cero = 0  │
│ assert                   │ invariantes de debug, no errores  │
│ bool keyboard[]          │ estado binario, indexado directo  │
│ static en validadores    │ encapsulación, no-API pública     │
│ const keyboard_map       │ inmutable, en .rodata            │
│ forward declaration      │ romper dependencia circular       │
│ include guards           │ prevenir redefinición múltiple    │
│ goto out                 │ salir de anidación múltiple       │
│ compilación separada     │ recompilar solo lo cambiado       │
└──────────────────────────┴──────────────────────────────────┘
```

---

## Referencias

- [Cowgod's CHIP-8 Technical Reference v1.0](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM) — Referencia primaria de opcodes y memoria
- [Tobias V. Langhoff — Guide to making a CHIP-8 emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/) — Guía moderna
- [ISO C11 Standard — unsigned char, memset, assert](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf) — Especificación del lenguaje
- [SDL3 Documentation](https://wiki.libsdl.org/SDL3/) — SDL3 API reference
