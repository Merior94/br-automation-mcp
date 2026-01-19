# B&R Automation Studio MCP Server Launcher
# This script is called by Claude Code from WSL2 via PowerShell interop

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Change to the server directory
Set-Location $ScriptDir

# Run the Python MCP server
# The server communicates via stdin/stdout for MCP stdio transport
python server.py
