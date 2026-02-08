# Migration Plan: Yarn to pnpm

## Goal
Migrate the project from yarn to pnpm with pinned (exact) dependency versions to ensure reproducible builds and better dependency management.

## Prerequisites
- Ensure pnpm is installed globally (`npm install -g pnpm` or `brew install pnpm`)
- Node.js version should be compatible (current setup uses Node.js as specified in project)

## Migration Steps

### 1. Create .npmrc for exact version pinning
Create `.npmrc` in project root with:
```
save-exact=true
```
This ensures all future `pnpm add` commands will save exact versions (no `^` or `~` prefixes).

### 2. Update package.json dependencies to exact versions
Remove all `^` and `~` prefixes from dependencies:
- `"@hotwired/stimulus": "^3.0.1"` → `"@hotwired/stimulus": "3.0.1"`
- Apply to all 12 dependencies

### 3. Remove yarn artifacts
```bash
rm yarn.lock
rm yarn-error.log
```

### 4. Initialize pnpm
```bash
pnpm install
```
This will:
- Read package.json
- Create `pnpm-lock.yaml`
- Install all dependencies to `node_modules/`

### 5. Update Procfile.dev
Replace yarn commands with pnpm:
```
web: bin/rails server -p 3000
js: pnpm build --watch
css: pnpm build:css --watch
```

### 6. Update bin/setup
Add pnpm install step after bundle install:
```ruby
puts "\n== Installing JavaScript dependencies =="
system! "pnpm install"
```

### 7. Update documentation files
Update all documentation files that reference yarn:

**CLAUDE.md** - "Common Development Commands" section:
- Change `yarn install` → `pnpm install`
- Change `yarn build --watch` → `pnpm build --watch`
- Change `yarn build:css --watch` → `pnpm build:css --watch`
- Change `yarn build` → `pnpm build`
- Change `yarn build:css` → `pnpm build:css`

**AGENTS.md** - Same changes as CLAUDE.md in relevant sections

**docs/plans/containerization.md** - Update build instructions:
- Change `yarn install --frozen-lockfile` → `pnpm install --frozen-lockfile`
- Change `yarn build` → `pnpm build`
- Change `yarn build:css` → `pnpm build:css`

### 8. Update .gitignore (if needed)
Ensure yarn-specific files are not tracked and pnpm files are handled correctly:
- Remove or keep `yarn.lock` in gitignore (should be removed from tracking)
- Ensure `pnpm-lock.yaml` is NOT in gitignore (should be committed)
- Keep `node_modules/` ignored

### 9. Test the migration
```bash
# Clean install
rm -rf node_modules
pnpm install

# Test build scripts
pnpm build
pnpm build:css

# Test dev server
bin/dev
```

### 10. Commit changes
Create atomic commits:
1. Add .npmrc configuration
2. Update package.json to exact versions
3. Add pnpm-lock.yaml and remove yarn files
4. Update Procfile.dev and bin/setup
5. Update documentation (CLAUDE.md, AGENTS.md, containerization.md)

## Verification Checklist
- [ ] `.npmrc` exists with `save-exact=true`
- [ ] All package.json dependencies use exact versions (no `^` or `~`)
- [ ] `pnpm-lock.yaml` exists and is committed
- [ ] `yarn.lock` and `yarn-error.log` are deleted
- [ ] Procfile.dev uses pnpm commands
- [ ] bin/setup includes pnpm install
- [ ] CLAUDE.md updated with pnpm commands
- [ ] AGENTS.md updated with pnpm commands
- [ ] docs/plans/containerization.md updated with pnpm commands
- [ ] `pnpm install` runs successfully
- [ ] `pnpm build` works
- [ ] `pnpm build:css` works
- [ ] `bin/dev` starts all services correctly
- [ ] Assets compile correctly

## Benefits of pnpm
- **Disk space efficiency**: Uses content-addressable storage, shares packages across projects
- **Speed**: Faster installation due to hard linking
- **Strict**: Better at catching phantom dependencies (dependencies not declared in package.json)
- **Exact versions**: Combined with .npmrc, ensures reproducible builds

## Rollback Plan
If issues arise:
1. Keep old `yarn.lock` in git history
2. Run `git checkout HEAD~1 yarn.lock`
3. Run `yarn install`
4. Revert Procfile.dev and bin/setup changes

## Notes
- pnpm uses a different node_modules structure (symlinks), but this should be transparent to build tools
- All npm/yarn scripts work with pnpm (drop-in replacement)
- Future package additions should use: `pnpm add <package>` (will automatically use exact version)
