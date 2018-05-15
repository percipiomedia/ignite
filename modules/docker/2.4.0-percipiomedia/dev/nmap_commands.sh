#!/bin/bash

# Show network interfaces and routes
nmap --iflist

# Scan ports
nmap -p 47100,47500,10800 localhost

# Network Response Time Test
nmap -sS -P0 -n -p 47100, 47500 -d3 172.19.0.2/16

# Scan network
nmap -sP 172.19.0.2/16