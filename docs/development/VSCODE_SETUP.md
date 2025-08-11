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

## Configuration Files

Create these files in your `.vscode/` directory:

### `.vscode/tasks.json`
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "swift: build",
            "type": "shell",
            "command": "swift",
            "args": ["build"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "problemMatcher": ["$swiftc"]
        },
        {
            "label": "swift: run server",
            "type": "shell",
            "command": "swift",
            "args": ["run", "App", "serve", "--hostname", "0.0.0.0", "--port", "8080"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": true,
                "panel": "dedicated",
                "clear": true
            },
            "isBackground": true,
            "problemMatcher": [{
                "pattern": [{
                    "regexp": ".*",
                    "file": 1,
                    "location": 2,
                    "message": 3
                }],
                "background": {
                    "activeOnStart": true,
                    "beginsPattern": "Building for debugging...",
                    "endsPattern": "Server starting on"
                }
            }],
            "options": {
                "env": {
                    "JWT_KEY": "development_jwt_secret_key_minimum_32_characters_required_for_security",
                    "DATABASE_HOST": "localhost",
                    "DATABASE_NAME": "project_rulebook_dev", 
                    "DATABASE_USERNAME": "vapor",
                    "DATABASE_PASSWORD": "password",
                    "DATABASE_PORT": "5432",
                    "BASE_URL": "http://localhost:8080",
                    "APPLICATION_IDENTIFIER": "com.dev.app",
                    "BREVO_API_KEY": "dev_brevo_key",
                    "BREVO_URL": "https://api.brevo.com",
                    "OPENAI_KEY": "dev_openai_key"
                }
            }
        },
        {
            "label": "swift: test",
            "type": "shell",
            "command": "swift",
            "args": ["test"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "problemMatcher": ["$swiftc"]
        }
    ]
}
```

### `.vscode/launch.json`
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Run Vapor Server",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/.build/debug/App",
            "args": ["serve", "--hostname", "0.0.0.0", "--port", "8080"],
            "cwd": "${workspaceFolder}",
            "env": {
                "JWT_KEY": "development_jwt_secret_key_minimum_32_characters_required_for_security",
                "DATABASE_HOST": "localhost",
                "DATABASE_NAME": "project_rulebook_dev",
                "DATABASE_USERNAME": "vapor", 
                "DATABASE_PASSWORD": "password",
                "DATABASE_PORT": "5432",
                "BASE_URL": "http://localhost:8080",
                "APPLICATION_IDENTIFIER": "com.dev.app",
                "BREVO_API_KEY": "dev_brevo_key",
                "BREVO_URL": "https://api.brevo.com",
                "OPENAI_KEY": "dev_openai_key"
            },
            "preLaunchTask": "swift: build",
            "console": "integratedTerminal",
            "stopOnEntry": false
        }
    ]
}
```

### `.vscode/settings.json`
```json
{
    "lldb.library": "/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/LLDB",
    "lldb.launch.expressions": "native",
    "swift.path": "/usr/bin/swift",
    "swift.buildPath": ".build",
    "swift.packagePath": ".",
    "files.watcherExclude": {
        "**/.build": true,
        "**/Packages": true,
        "**/.git": true
    },
    "files.exclude": {
        "**/.build": true,
        "**/Packages": true,
        "**/.DS_Store": true,
        "**/DerivedData": true,
        "**/*.xcodeproj": true
    },
    "search.exclude": {
        "**/.build": true,
        "**/Packages": true
    },
    "[swift]": {
        "editor.tabSize": 4,
        "editor.insertSpaces": true,
        "editor.formatOnSave": true
    },
    "terminal.integrated.env.osx": {
        "JWT_KEY": "development_jwt_secret_key_minimum_32_characters_required_for_security",
        "DATABASE_HOST": "localhost",
        "DATABASE_NAME": "project_rulebook_dev",
        "DATABASE_USERNAME": "vapor",
        "DATABASE_PASSWORD": "password",
        "DATABASE_PORT": "5432",
        "BASE_URL": "http://localhost:8080",
        "APPLICATION_IDENTIFIER": "com.dev.app"
    }
}
```

### `.vscode/keybindings.json`
```json
[
    {
        "key": "cmd+r",
        "command": "workbench.action.tasks.runTask",
        "args": "swift: run server",
        "when": "!inDebugMode"
    },
    {
        "key": "cmd+shift+r",
        "command": "workbench.action.debug.start",
        "when": "!inDebugMode"
    },
    {
        "key": "cmd+b",
        "command": "workbench.action.tasks.runTask", 
        "args": "swift: build"
    },
    {
        "key": "cmd+shift+t",
        "command": "workbench.action.tasks.runTask",
        "args": "swift: test"
    }
]
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