# LC-3 Fixed-Point Calculator

A calculator written in LC-3 assembly that supports addition, subtraction, multiplication, division, and exponentiation on decimal numbers with one decimal digit.

## Description

This program runs on the LC-3 architecture and implements a basic calculator. Numbers are represented in fixed-point format (scaled by 10 internally), so a value like `3.7` is stored as `37`. This allows the LC-3 to handle one decimal digit of precision without any special hardware.

**Supported operators:**

| Operator | Symbol | Example Input |
|----------|--------|---------------|
| Addition | `+` | `3.2+1.5` |
| Subtraction | `-` | `9.0-4.3` |
| Multiplication | `*` | `2.5*2.0` |
| Division | `/` | `7.0/2.0` |
| Exponentiation | `^` | `2.0^3.0` |

**Input format:** `num1[.frac1] op num2[.frac2]`

Each number is a single digit optionally followed by a `.` and one fractional digit (e.g. `4`, `4.2`, `0.5`). Spaces are not supported.

**Example:**
```
Calculate: 3.5+1.2
 = 4.7

Calculate: 2.0*3.0
 = 6.0

Calculate: 9.0/4.0
 = 2.2
```

> **Note:** Exponentiation uses only the integer part of the exponent (e.g. `2.0^3.7` is treated as `2.0^3`). Large exponents will overflow the registers.

## Simulator

This program was written and tested using **LC3Tools**:

https://github.com/chiragsakhuja/lc3tools/releases

## Requirements

- LC-3 v2.0.x simulator
- The program loads at address `x3000` and uses a software stack initialized at `xFE00`
- No graphics output - all I/O is text-based via the LC-3 console (TRAP x20/x21/x22)

## Usage

1. Assemble `calculator.asm` using your LC-3 assembler
2. Load the resulting `.obj` file into your simulator
3. Run from address `x3000`
4. Enter expressions at the `Calculate:` prompt

## Limitations

- Only single-digit integers with one decimal digit per operand (e.g. `9.9` max per number)
- No negative number input (results can be negative; inputs cannot)
- Division and multiplication results are truncated down, not rounded
- Exponentiation overflows for large values due to 16-bit register limits

## Author

Konner Knoll - 05/12/2026
