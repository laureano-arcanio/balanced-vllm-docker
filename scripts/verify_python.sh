#!/bin/bash

# Script to verify Python version in the container
echo "System Python version:"
python --version

echo "Python 3.12 version:"
python3.12 --version

echo "Virtual environment 1 Python version:"
/opt/venv1/bin/python --version

echo "Virtual environment 2 Python version:"
/opt/venv2/bin/python --version

echo "Pip versions:"
echo "System pip: $(pip --version)"
echo "venv1 pip: $(/opt/venv1/bin/pip --version)"
echo "venv2 pip: $(/opt/venv2/bin/pip --version)"
