# pn-plugins Marketplace

Welcome to **pn-plugins** — the official Paradigm Networks plugin marketplace for Claude Code and Cursor.

This repository hosts a curated collection of tools and extensions that enhance your development workflow with AI-powered features.

## 📦 Available Plugins

### [pn-repo-beacon](./pn-repo-beacon)

Automatically injects git repository context into every Claude Code and Cursor tool call. This ensures Claude and Cursor always know which repository and branch you're working in.

**Features:**
- Automatic git repo detection
- Context injection on every prompt and tool call
- Multi-repo workspace support
- Credential-safe (strips embedded userinfo from URLs)
- Fail-safe design (never blocks operations)

**Installation:**
```bash
# From GitHub
claude /plugin install github:ParadigmNetworks-ai/pn-plugins

# Or from local directory (development)
claude --plugin-dir ./pn-repo-beacon
```

**Documentation:** See [pn-repo-beacon/README.md](./pn-repo-beacon/README.md)

---

## 🚀 Getting Started

### For Users

1. **Add the marketplace** (optional, for easier discovery):
   ```bash
   claude /plugin marketplace add github:ParadigmNetworks-ai/pn-plugins
   ```

2. **Install a plugin**:
   ```bash
   claude /plugin install pn-plugins/pn-repo-beacon
   ```

3. **Verify installation**:
   ```bash
   claude /plugin list
   ```

### For Developers

Each plugin is a self-contained directory with:
- `.claude-plugin/` — Claude Code configuration
- `.cursor-plugin/` — Cursor configuration
- `hooks/` — Event handlers
- `scripts/` — Implementation logic
- `README.md` — Plugin documentation

See individual plugin READMEs for development and testing instructions.

---

## 📋 Plugin Structure

```
pn-plugins/
├── marketplace.json          # Marketplace catalog
├── README.md                 # This file
├── pn-repo-beacon/           # First plugin
│   ├── .claude-plugin/
│   ├── .cursor-plugin/
│   ├── hooks/
│   ├── hooks-cursor/
│   ├── scripts/
│   ├── README.md
│   └── LICENSE
└── pn-code-reviewer/         # Future plugins
    └── ...
```

---

## 🔄 Contributing

### Adding a New Plugin

1. Create a plugin directory: `mkdir pn-new-plugin`
2. Follow the structure of [pn-repo-beacon](./pn-repo-beacon)
3. Test thoroughly in development environment
4. Update `marketplace.json` to list your plugin
5. Submit a PR with documentation

### Plugin Requirements

- ✅ Works on Claude Code and/or Cursor
- ✅ Comprehensive README with installation & usage
- ✅ Error handling and fail-safe design
- ✅ Proper git configuration (plugin.json, hooks.json)
- ✅ MIT or compatible open-source license

---

## 📝 License

Each plugin includes its own LICENSE file. Most PN plugins are licensed under MIT.

---


## 🔗 Links

- **GitHub**: [github.com/ParadigmNetworks-ai/pn-plugins](https://github.com/ParadigmNetworks-ai/pn-plugins)
- **Paradigm Networks**: [paradigmnetworks.ai](https://paradigmnetworks.ai)
- **Claude Code Docs**: [code.claude.com](https://code.claude.com)

