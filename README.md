# B&R Automation Studio MCP Server

An [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server that enables AI assistants like Claude to interact with B&R Automation Studio projects. Build projects, run simulators, and read/write OPC UA variables - all through natural language.

> **This is a fork of [AndrewMusser/br-automation-mcp](https://github.com/AndrewMusser/br-automation-mcp), adapted for Automation Studio 6.x / RUC6.** The original targets AS4.x - see [Changes in This Fork](#changes-in-this-fork-automation-studio-6x-support) below for what's different.

## Features

- **Build Projects** - Compile Automation Studio projects for simulation
- **Run Simulator** - Launch ARsim and connect automatically
- **OPC UA Integration** - Read and write PLC variables in real-time

## Changes in This Fork (Automation Studio 6.x Support)

This fork adapts the original server (written for Automation Studio 4.x) to work with Automation Studio 6.x / RUC6. Key differences from upstream:

- **Increased build timeout** - `build_automation_studio_project`'s subprocess timeout was raised from 60s to 600s, since some bigger projects may take longer to build.
- **Two-step RUC packaging** - On this AS6 install, `BR.AS.Build.exe -buildRUCPackage` combined with `-simulation` fails with `error 511: Missing command line option '-C'` (an undocumented AS6 quirk). Build and RUC packaging are now done as two separate steps: `BR.AS.Build.exe` with `-all -simulation`, followed by a separate `BR.AS.RUCPackageCreator.exe` call (its own 180s timeout), matching B&R's documented [command-line RUC workflow](https://help.br-automation.com/#/en/6/automationruntime/enhancedtransfer/handling/export_ruc/export_ruc_commandline.html).
- **Build success detection** - `BR.AS.Build.exe` can exit with a non-zero return code even when the compile has 0 errors (e.g. due to security or licensing warnings). Success is now determined by parsing the `Build: N error(s)` summary line instead of trusting the process return code.
- **Updated tool paths** for AS6/PVI6 installations:
  - `AS_BUILD_PATH` -> `C:\Program Files (x86)\BRAutomation\AS6\bin-en\BR.AS.Build.exe`
  - `AS_RUC_PACKAGE_CREATOR_PATH` (new) -> `C:\Program Files (x86)\BRAutomation\AS6\bin-en\BR.AS.RUCPackageCreator.exe`
  - `PVI_TRANSFER_PATH` -> `C:\BrAutomation\PVI6\PVI\Tools\PVITransfer\PVITransfer.exe`
- **Simulator launch via `OfflineCommissioning`** - The AS4/RUC5 PIL command `CreateARsimStructure` was removed in AS6/RUC6 (PVITransfer rejects it with `Unknown command`). It's replaced with the AS6 equivalent, `OfflineCommissioning ... "ARSim" ...`, which also starts the simulator itself, so there's no need to separately launch `ar000loader.exe` via `subprocess.Popen` anymore.
- **Anonymous OPC UA by default** - `OPCUA_USERNAME` / `OPCUA_PASSWORD` now default to empty strings (anonymous connection), instead of the original `Admin` / `password` defaults.

If you're targeting AS4.x, the upstream paths/commands should still apply as-is - check your AS/RUC version before carrying these changes over.

## Prerequisites

- **Windows 10/11** with B&R Automation Studio 4.x or 6.x installed
- **Python 3.10+** on Windows (with pip)
- **Claude Code** (native Windows or WSL2)

## Installation

### 1. Clone this repository

```powershell
git clone https://github.com/AndrewMusser/br-automation-mcp.git
cd br-automation-mcp
```

### 2. Install Python dependencies

```powershell
pip install -r requirements.txt
```

### 3. Configure server settings

Edit `server.py` to match your environment:

#### 3a. B&R Tool Paths

Update these paths to match your Automation Studio installation:

```python
AS_BUILD_PATH = "C:\\BrAutomation\\AS412\\bin-en\\BR.AS.Build.exe"
PVI_TRANSFER_PATH = "C:\\BrAutomation\\PVI\\V4.12\\PVI\\Tools\\PVITransfer\\PVITransfer.exe"
```

Common installation locations:
- **AS 4.12:** `C:\BrAutomation\AS412\bin-en\BR.AS.Build.exe`
- **AS 4.9:** `C:\BrAutomation\AS49\bin-en\BR.AS.Build.exe`
- **PVI:** Typically under `C:\BrAutomation\PVI\V4.x\PVI\Tools\PVITransfer\`

#### 3b. OPC UA Parameters

Configure the OPC UA connection settings for communicating with ARsim:

```python
OPCUA_HOST = "localhost"
OPCUA_PORT = 4840
OPCUA_USERNAME = "Admin"
OPCUA_PASSWORD = "password"
```

**Important:** These credentials must match your Automation Studio project's OPC UA configuration:
- User/role settings: `Physical/<Config>/<CPU>/AccessAndSecurity/UserRoleSystem/`
- OPC UA config: `Physical/<Config>/<CPU>/Connectivity/OpcUA/`

### 4. Configure Claude Code

Choose the setup that matches how you run Claude Code:

---

#### Option A: Native Windows (Recommended)

Claude Code now runs natively on Windows via Git Bash, PowerShell, or CMD. This is the simplest setup since both Claude Code and Automation Studio run on the same machine.

**Install Claude Code on Windows:**
```powershell
winget install Anthropic.ClaudeCode
```

**Configuration file:** `%APPDATA%\Claude\settings.json`

**Add to settings:**
```json
{
  "mcpServers": [
    {
      "name": "br-automation-mcp",
      "type": "stdio",
      "command": "python",
      "args": ["D:\\path\\to\\br-automation-mcp\\server.py"],
      "enabled": true
    }
  ]
}
```

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│  Windows                                                    │
│                                                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │ Claude Code │───▶│  server.py (MCP STDIO Server)       │ │
│  │ (Git Bash)  │    └───────────────┬─────────────────────┘ │
│  └─────────────┘                    │                       │
│                                     │                       │
│         ┌───────────────────────────┼───────────────┐       │
│         ▼                           ▼               ▼       │
│  ┌─────────────┐          ┌──────────────┐  ┌─────────┐     │
│  │ BR.AS.Build │          │ PVITransfer  │  │  OPC UA │     │
│  │   (Build)   │          │  (Simulate)  │  │  (Test) │     │
│  └─────────────┘          └──────────────┘  └─────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

#### Option B: WSL2 (Cross-Platform)

If you run Claude Code in WSL2, it can invoke the Windows Python server via PowerShell interop.

**Configuration file:** `~/.claude/settings.json`

**Add to settings:**
```json
{
  "mcpServers": [
    {
      "name": "br-automation-mcp",
      "type": "stdio",
      "command": "powershell.exe",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "D:\\path\\to\\br-automation-mcp\\run-server.ps1"
      ],
      "enabled": true
    }
  ]
}
```

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│  WSL2 (Linux)                                               │
│  ┌─────────────────┐                                        │
│  │   Claude Code   │                                        │
│  │                 │──── powershell.exe ────┐               │
│  └─────────────────┘                        │               │
└─────────────────────────────────────────────│───────────────┘
                                              │
┌─────────────────────────────────────────────│───────────────┐
│  Windows                                    ▼               │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │  run-server.ps1 │───▶│  server.py (MCP STDIO Server)   │ │
│  └─────────────────┘    └───────────────┬─────────────────┘ │
│                                         │                   │
│         ┌───────────────────────────────┼───────────────┐   │
│         ▼                               ▼               ▼   │
│  ┌─────────────┐              ┌──────────────┐  ┌─────────┐ │
│  │ BR.AS.Build │              │ PVITransfer  │  │  ARsim  │ │
│  │   (Build)   │              │  (Simulate)  │  │ (OPC UA)│ │
│  └─────────────┘              └──────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

### 5. Restart Claude Code

After updating the configuration, restart Claude Code to load the MCP server.

## Available Tools

### `build_automation_studio_project`

Compiles an Automation Studio project for simulation.

**Parameters:**
- `project_file` - Path to the .apj file (Windows path)
- `configuration` - Name of the configuration to build

**Example prompt:** "Build my project at D:\Projects\MyApp\MyApp.apj using the X20CPU configuration"

### `run_automation_studio_simulator`

Creates ARsim structure and launches the simulator.

**Parameters:**
- `ruc_package` - Path to RUCPackage.zip (generated by build)
- `start_simulator` - Whether to start immediately (default: true)

**Example prompt:** "Start the simulator using the RUC package at D:\Projects\MyApp\Binaries\X20CPU\X20CP1686X\RUCPackage\RUCPackage.zip"

### `opcua_read_write`

Reads or writes OPC UA variables on the running simulator.

**Parameters:**
- `node_id` - OPC UA node identifier (e.g., `ns=6;s=::TaskName:varName`)
- `operation` - "read" or "write"
- `value` - Value to write (for write operations)
- `value_type` - Data type: Boolean, Int16, Int32, Float, Double, String

**Example prompts:**
- "Read the temperature variable from the TempCtrl task"
- "Set the targetTemp to 75.0 in the TempCtrl task"

## OPC UA Node ID Format

For task-local variables:
```
ns=6;s=::<TaskName>:<VariableName>
```

For global variables:
```
ns=6;s=::AsGlobalPV:<VariablePath>
```

**Note:** Variables must be exposed in the OPC UA configuration (OpcUaMap.uad) to be accessible.

## Troubleshooting

### "Command not found" errors
Ensure Python is in your Windows PATH and the B&R tool paths in `server.py` are correct.

### OPC UA connection failures
- Verify the simulator is running
- Check that variables are exposed in OpcUaMap.uad
- Default credentials are Admin/password

### WSL2 can't find powershell.exe
Ensure WSL2 has Windows interop enabled (default). Check with:
```bash
which powershell.exe
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Acknowledgments

- [Model Context Protocol](https://modelcontextprotocol.io/) by Anthropic
- [FastMCP](https://github.com/jlowin/fastmcp) for the Python MCP SDK
- [B&R Automation](https://www.br-automation.com/) for Automation Studio
