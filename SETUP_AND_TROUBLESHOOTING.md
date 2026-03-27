# OpenSage Setup and Troubleshooting Guide

This document covers common setup issues and their solutions for running OpenSage agents locally.

## Prerequisites

- Python >= 3.12
- Docker (required for the `native` sandbox backend)
- uv (dependency manager)
- Local LLM running (optional, e.g., Ollama for local models)

## Installation

### 1. Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Add to PATH if needed:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 2. Install Python and dependencies

```bash
cd /path/to/opensage
uv python install
uv sync
```

### 3. Verify Dependencies

```bash
uv run opensage dependency-check
```

Expected output:
```
Checking Docker...
  ✓ Docker daemon is running and accessible
```

### 4. Install opensage CLI globally

```bash
cd /path/to/opensage
uv pip install -e .

# Add to PATH in ~/.zshrc or ~/.bashrc
export PATH="/path/to/opensage/.venv/bin:$PATH"
```

Then you can use `opensage` directly from anywhere:
```bash
opensage dependency-check
opensage web --agent examples/agents/my_ollama_agent --port 8000
```

## Running OpenSage Web UI

### Quick Start

```bash
./run_web.sh
```

Or manually:

```bash
opensage web --agent examples/agents/my_ollama_agent --port 8000
```

Access at: **http://localhost:8000**

## Docker Images and Containers

### Current State

Check what Docker images and containers you have:

```bash
docker images
docker ps -a
```

### Available OpenSage Images

OpenSage has several pre-built Dockerfiles for different sandbox backends:

1. **main** - Primary execution sandbox (Ubuntu-based)
   ```bash
   docker build -f src/opensage/templates/dockerfiles/main/Dockerfile -t opensage/main:latest .
   ```

2. **neo4j** - Graph database for memory/tracing
   ```bash
   docker build -f src/opensage/templates/dockerfiles/neo4j/Dockerfile -t opensage/neo4j:latest .
   ```

3. **joern** - Static analysis framework
4. **codeql** - CodeQL static analysis
5. **coverage** - Coverage instrumentation
6. **gdb_mcp** - GDB debugger via MCP
7. **pdb_mcp** - Python debugger via MCP

### Build Custom Images

Build all sandbox images:
```bash
cd /path/to/opensage
for dockerfile in src/opensage/templates/dockerfiles/*/Dockerfile; do
  name=$(basename $(dirname $dockerfile))
  docker build -f $dockerfile -t opensage/$name:latest .
done
```

Build a specific image:
```bash
docker build -f src/opensage/templates/dockerfiles/main/Dockerfile -t opensage/main:latest .
```

### Clean Up Docker

Remove all stopped containers and unused images:
```bash
docker system prune -a --volumes -f
```

## Common Errors and Fixes

### Error 1: `KeyError: 'main'` - Sandbox Not Configured

**Symptom:**
```
KeyError: 'main'
  File "opensage/toolbox/general/bash_tool.py", line 17, in bash_tool_main
    sandbox = get_sandbox_from_context(tool_context, "main")
```

**Cause:** Agent uses `bash_tool_main` but no "main" sandbox is configured.

**Fix:**

**Option A: Remove bash tool from agent** (recommended for simple agents)

Edit `agent.py`:
```python
from opensage.agents.opensage_agent import OpenSageAgent

def mk_agent(opensage_session_id: str):
    return OpenSageAgent(
        name="my_agent",
        model=LiteLlm(...),
        description="...",
        instruction="...",
        tools=[],  # No tools = no sandbox needed
    )
```

**Option B: Configure sandbox in config.toml**

Edit `config.toml`:
```toml
[sandbox]
backend = "native"

[sandbox.sandboxes.main]
image = "ubuntu:24.04"

[model]
```

Then ensure the image exists:
```bash
docker pull ubuntu:24.04
```

---

### Error 2: `AttributeError: 'list' object has no attribute 'items'` - Invalid Config Format

**Symptom:**
```
AttributeError: 'list' object has no attribute 'items'
  File "opensage/config/config_dataclass.py", line 622, in _preprocess_config_data
    for sandbox_name, sandbox_cfg in sandboxes_data.items():
```

**Cause:** Sandboxes defined as TOML array `[[sandbox.sandboxes]]` instead of dict.

**Fix:**

Use dict format in `config.toml`:
```toml
# ✗ WRONG
[[sandbox.sandboxes]]
name = "main"
image = "ubuntu:24.04"

# ✓ CORRECT
[sandbox.sandboxes.main]
image = "ubuntu:24.04"
```

---

### Error 3: Docker IP Allocation Timeout - Docker Network Issue (macOS)

**Symptom:**
```
INFO:opensage.sandbox.native_docker_sandbox:Retrying IP allocation, attempt 15
INFO:opensage.sandbox.native_docker_sandbox:Retrying IP allocation, attempt 20
INFO:opensage.sandbox.native_docker_sandbox:Retrying IP allocation, attempt 25
```

Web UI hangs, then times out.

**Cause:** OpenSage tries to reserve loopback IPs (127.0.0.x) for port binding on macOS Docker Desktop, which doesn't work reliably due to Docker Desktop's virtualized network isolation.

**Root Issue:** OpenSage's sandbox IP allocation was designed for Linux Docker (where loopback binding works), not macOS Docker Desktop.

**Fix:**

**Quick fix (recommended):** Use agents with `tools=[]` to avoid sandbox initialization:
```python
def mk_agent(opensage_session_id: str):
    return OpenSageAgent(
        name="my_agent",
        model=LiteLlm(...),
        tools=[],  # No tools = no port binding needed
    )
```

**Alternative:** Configure sandboxes to use Docker network instead of loopback binding:
```toml
[sandbox]
backend = "native"
network = "bridge"  # Use Docker bridge network instead of loopback
```

**Nuclear option:** Restart Docker Desktop
- Quit Docker completely
- Reopen it
- Wait for the engine to fully start
- Retry

---

### Error 4: Image Pull Failed - Image Doesn't Exist

**Symptom:**
```
Error response from daemon: pull access denied for opensage/main, repository does not exist
```

**Cause:** Custom image like `opensage/main:latest` doesn't exist on Docker Hub or locally.

**Fix:**

Use standard images in `config.toml`:
```toml
[sandbox.sandboxes.main]
image = "ubuntu:24.04"  # ✓ Use standard images
# image = "opensage/main:latest"  # ✗ Doesn't exist
```

**If you need the custom image**, build it locally:
```bash
cd /path/to/opensage
docker build -f src/opensage/templates/dockerfiles/main/Dockerfile -t opensage/main:latest .
```

Note: This takes 5-10 minutes as it builds a large base image.

---

### Error 5: Neo4j Memory Logging Warnings

**Symptom:**
```
WARNING:opensage.patches.neo4j_logging:Failed to initialize agent memory dir: 'main'
WARNING:opensage.patches.neo4j_logging:Failed to record topology agent start: 'main'
```

**Cause:** Neo4j not configured (optional feature).

**Status:** Non-critical warnings. Agent still works. Ignore if you don't need memory logging.

**Fix (if needed):**

Configure Neo4j in `config.toml`:
```toml
[neo4j]
uri = "bolt://localhost:7687"
username = "neo4j"
password = "password"
```

Then start a Neo4j container:
```bash
docker run -d --name neo4j -p 7687:7687 -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/password \
  neo4j:latest
```

---

## Creating a Simple Agent

### Minimal Agent Setup

```
my_agent/
├── agent.py
├── config.toml
└── __init__.py
```

**agent.py:**
```python
from google.adk.models.lite_llm import LiteLlm
from opensage.agents.opensage_agent import OpenSageAgent

def mk_agent(opensage_session_id: str):
    return OpenSageAgent(
        name="my_agent",
        model=LiteLlm(
            model="ollama/qwen2.5:0.5b",
            api_base="http://localhost:11434",
        ),
        description="A simple agent.",
        instruction="You are a helpful assistant.",
        tools=[],  # No tools = minimal, no sandboxes needed
    )
```

**config.toml:**
```toml
[sandbox]
backend = "native"

[model]
```

**Run it:**
```bash
opensage web --agent my_agent --port 8000
```

---

## Running with Bash Tool (Advanced)

If you need bash execution, add the sandbox and tool:

**agent.py:**
```python
from opensage.toolbox.general.bash_tool import bash_tool_main

def mk_agent(opensage_session_id: str):
    return OpenSageAgent(
        name="my_agent",
        model=LiteLlm(...),
        tools=[bash_tool_main],
    )
```

**config.toml:**
```toml
[sandbox]
backend = "native"
network = "bridge"  # Recommended for macOS

[sandbox.sandboxes.main]
image = "ubuntu:24.04"

[model]
```

**Ensure image exists:**
```bash
docker pull ubuntu:24.04
```

---

## Session Management

### Resume a Session

```bash
opensage web --resume
```

Restores the latest saved session snapshot.

### Resume Specific Session

```bash
opensage web --resume-from <session_id_or_path>
```

Sessions are saved under `~/.local/opensage/sessions/`

---

## Docker Network Troubleshooting (macOS)

If you keep getting IP allocation retries:

1. **Check available networks:**
   ```bash
   docker network ls
   ```

2. **Inspect network:**
   ```bash
   docker network inspect bridge
   ```

3. **Check Docker logs:**
   ```bash
   # macOS
   cat ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log
   ```

4. **Nuclear option:**
   - Docker Desktop → Preferences → Reset → **Reset Docker to factory defaults**
   - This clears all containers/images/networks

---

## Performance Tips

1. **Use `tools=[]`** for chat-only agents (no sandbox overhead)
2. **Keep agent config minimal** - only define needed sandboxes
3. **Clean up periodically:**
   ```bash
   docker system prune -a --volumes -f
   ```
4. **Pin image versions** in config instead of `latest`:
   ```toml
   image = "ubuntu:24.04"  # Specific version
   ```

---

## Testing Your Setup

### Minimal Test

```bash
cd /path/to/opensage
opensage web --agent examples/agents/my_ollama_agent --port 8000
```

If it starts and connects to http://localhost:8000, setup is working.

### Full Test with Bash Tool

1. Create an agent with `bash_tool_main`
2. Configure the "main" sandbox with `ubuntu:24.04`
3. Type in chat: "What is 2+2?" or "ls -la"
4. Verify bash command executes in the sandbox

---

## Bash Script Helper

A bash script `run_web.sh` is provided to start the Web UI:

```bash
# Default (my_ollama_agent on port 8000)
./run_web.sh

# Specific agent
./run_web.sh examples/agents/poc_agent_dynamic_tools

# Custom port
./run_web.sh examples/agents/my_ollama_agent 9000
```

---

## Additional Resources

- [OpenSage Docs](https://docs.opensage-agent.ai)
- [Docker Documentation](https://docs.docker.com/)
- [uv Documentation](https://docs.astral.sh/uv/)

