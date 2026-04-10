# MIPS 32-bit Processor (Single Cycle, Multicycle & Pipelined)

## 📌 Overview
This repository contains the design and implementation of a 32-bit MIPS processor in three architectures:
- Single Cycle
- Multicycle
- 5-Stage Pipelined

Implemented using Verilog HDL.

---

## 🧠 Architectures

### ▶ Single Cycle
- Executes instructions in one clock cycle
- Simple design but higher critical path delay

### ▶ Multicycle
- Uses FSM-based control
- Efficient hardware utilization

### ▶ Pipelined
- 5 stages: IF, ID, EX, MEM, WB
- Hazard detection and forwarding implemented

---

## ⚙️ Features
- 32-bit architecture
- Supports R-type, I-type instructions
- Modular RTL design
- Pipeline hazard handling

---

## 🛠 Tools Used
- Verilog HDL
- Vivado

---
