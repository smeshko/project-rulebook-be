# VS Code Setup for Vapor Development

This guide sets up VS Code for optimal Vapor development with keyboard shortcuts and debugging support.

## Required Extensions

Install these VS Code extensions for the best Swift/Vapor development experience:

1. **Swift** (by Swift Server Work Group) - Essential for Swift language support
2. **CodeLLDB** (by Vadim Chugunov) - For debugging Swift applications  
3. **Better TOML** (by bungcip) - For Package.swift syntax highlighting

## Installation Commands

```bash
code --install-extension sswg.swift-lang
code --install-extension vadimcn.vscode-lldb
code --install-extension bungcip.better-toml
```

## Keyboard Shortcuts

The following keyboard shortcuts are configured for Vapor development:

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Cmd+R` | Run Server | Builds and starts the Vapor server |
| `Cmd+Shift+R` | Debug Server | Starts server with debugger attached |
| `Cmd+B` | Build | Builds the project without running |
| `Cmd+Shift+T` | Run Tests | Executes the test suite |

## Environment Variables

All required environment variables are automatically configured in the VS Code settings:

- `JWT_KEY` - Development JWT secret key
- `DATABASE_*` - Database connection settings  
- `BASE_URL` - Application base URL
- `APPLICATION_IDENTIFIER` - App identifier

## File Structure

The VS Code configuration includes these files:

```
.vscode/
├── tasks.json          # Build, run, and test tasks
├── launch.json         # Debug configurations
├── settings.json       # Workspace settings and environment
└── keybindings.json    # Custom keyboard shortcuts
```

## Usage Instructions

### 1. Running the Server
- **Quick Start**: Press `Cmd+R` to build and run the server
- **With Debugging**: Press `Cmd+Shift+R` to run with debugger
- **Manual**: Use Command Palette (`Cmd+Shift+P`) → "Tasks: Run Task" → "swift: run server"

### 2. Building the Project  
- **Keyboard**: Press `Cmd+B`
- **Manual**: Command Palette → "Tasks: Run Task" → "swift: build"

### 3. Running Tests
- **Keyboard**: Press `Cmd+Shift+T`  
- **Manual**: Command Palette → "Tasks: Run Task" → "swift: test"

### 4. Debugging
1. Set breakpoints by clicking in the gutter next to line numbers
2. Press `Cmd+Shift+R` or use the Debug panel
3. The server will start with the debugger attached
4. Access your app at `http://localhost:8080`

## Expected Output

When you run the server (`Cmd+R`), you should see:

```
Building for debugging...
[1/1] Write swift-version...
Build complete! 
[ INFO ] Configuration loaded for environment: development
[ INFO ] Database host: localhost  
[ INFO ] Services configured: Brevo, OpenAI
[ INFO ] Server starting on http://0.0.0.0:8080
```

## Troubleshooting

### Issue: "Swift command not found"
**Solution**: Ensure Swift is installed and in your PATH:
```bash
which swift
# Should output: /usr/bin/swift
```

### Issue: "CodeLLDB not working"
**Solution**: Make sure Xcode Command Line Tools are installed:
```bash
xcode-select --install
```

### Issue: "Environment variables not loaded"
**Solution**: The environment variables are configured in `.vscode/settings.json` and task definitions. They should load automatically.

### Issue: "Server won't start"
**Solution**: Check that no other process is using port 8080:
```bash
lsof -i :8080
# Kill any processes using the port if needed
```

## Advanced Configuration

### Custom Environment Variables
To add custom environment variables, edit `.vscode/settings.json` and add them to `terminal.integrated.env.osx`.

### Different Build Configurations
The tasks are configured for debug builds. To create release tasks, duplicate the tasks in `tasks.json` and change `swift build` to `swift build -c release`.

### Custom Port
To run on a different port, edit the `args` in `tasks.json` and `launch.json` and change the `--port` value.

## Integration with Other Editors

This configuration is VS Code-specific. For other editors:
- **Xcode**: See `XCODE_SETUP.md`  
- **Command Line**: Use `swift run App serve` directly
- **Other IDEs**: Adapt the environment variables and build commands as needed