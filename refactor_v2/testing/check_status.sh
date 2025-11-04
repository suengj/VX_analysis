#!/bin/bash

# Test Status Checker
# Quick script to check CVC and Imprinting test status

echo "========================================"
echo "VC ANALYSIS - TEST STATUS CHECK"
echo "========================================"
echo ""

# CVC Flow
echo "1. CVC FLOW STATUS:"
echo "----------------------------------------"

CVC_PID=86555
if ps -p $CVC_PID > /dev/null 2>&1; then
    echo "   Status: RUNNING (PID: $CVC_PID)"
    echo "   CPU/Memory:"
    ps -p $CVC_PID -o %cpu,%mem,etime,command | tail -1
else
    echo "   Status: NOT RUNNING"
fi

echo ""
echo "   Recent Progress:"
tail -3 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log 2>/dev/null || echo "   (No log available)"

echo ""
echo "   Generated Files:"
ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/data/*.csv 2>/dev/null | wc -l | xargs echo "     Data files:"
ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/results/*.csv 2>/dev/null | wc -l | xargs echo "     Results files:"

echo ""
echo ""

# Imprinting Flow
echo "2. IMPRINTING FLOW STATUS:"
echo "----------------------------------------"

if [ -f "/Users/suengj/Documents/Code/Python/Research/VC/testing_results/imprinting_flow/logs/full_execution.log" ]; then
    echo "   Status: CHECK LOG"
    echo "   Recent Progress:"
    tail -3 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/imprinting_flow/logs/full_execution.log 2>/dev/null
    
    echo ""
    echo "   Generated Files:"
    ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/imprinting_flow/data/*.csv 2>/dev/null | wc -l | xargs echo "     Data files:"
    ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/imprinting_flow/results/*.csv 2>/dev/null | wc -l | xargs echo "     Results files:"
else
    echo "   Status: NOT STARTED"
fi

echo ""
echo "========================================"
echo "Current Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

