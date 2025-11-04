#!/bin/bash
# Progress Monitoring Script for CVC Flow Testing

echo "======================================"
echo "CVC FLOW TESTING - PROGRESS CHECK"
echo "======================================"
echo ""

# Check if process is running
echo "1. Process Status:"
if ps -p 86076 > /dev/null 2>&1; then
    echo "   ✅ Process is RUNNING (PID: 86076)"
    echo "   CPU/Memory usage:"
    ps aux | grep "86076" | grep -v grep
else
    echo "   ⚠️  Process has COMPLETED or STOPPED"
fi
echo ""

# Check log file
echo "2. Latest Log Entries (last 20 lines):"
echo "--------------------------------------"
tail -20 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log
echo "--------------------------------------"
echo ""

# Check data files
echo "3. Generated Data Files:"
ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/data/*.csv 2>/dev/null | awk '{print "   ", $9, "-", $5}'
echo ""

# Check results files
echo "4. Generated Results Files:"
ls -lh /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/results/*.csv 2>/dev/null | awk '{print "   ", $9, "-", $5}'
echo ""

# Execution time
echo "5. Execution Status:"
if [ -f /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log ]; then
    FIRST_LINE=$(head -1 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log | grep "CVC FLOW TESTING STARTED")
    if [ ! -z "$FIRST_LINE" ]; then
        LAST_LINE=$(tail -1 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log)
        echo "   Start time: $(echo $FIRST_LINE | cut -d' ' -f5-6)"
        echo "   Last log: $LAST_LINE"
    fi
fi
echo ""

echo "======================================"
echo "To monitor in real-time, run:"
echo "  tail -f /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log"
echo "======================================"

