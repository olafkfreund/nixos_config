# Code Review Command

Perform a comprehensive, in-depth code review of Nix configuration files using the project's established patterns and anti-patterns documentation.

## Context Documents

**REQUIRED**: Review code against these authoritative documents:

1. **@docs/PATTERNS.md** - Comprehensive best practices guide
   - Module System Patterns
   - Package Writing Patterns
   - Configuration Patterns
   - Security Patterns
   - Performance Patterns

2. **@docs/NIXOS-ANTI-PATTERNS.md** - Critical anti-patterns to detect
   - Language Anti-Patterns
   - Module System Anti-Patterns
   - Security Anti-Patterns
   - Package Writing Anti-Patterns
   - Comprehensive Code Review Checklist

## Review Instructions

### Step 1: Identify Files to Review

Ask the user which files they want reviewed, or review recently changed files:

```bash
# Show recently modified Nix files
git diff --name-only HEAD | grep '.nix$'

# Or show staged files
git diff --cached --name-only | grep '.nix$'
```

### Step 2: Read and Analyze Files

For each file to review:
1. Read the entire file carefully
2. Understand the context (module, package, configuration)
3. Identify the purpose and scope

### Step 3: Comprehensive Pattern Analysis

**Check Against PATTERNS.md:**

#### Module System Review
- ✅ **Function-based module structure**: Module receives proper arguments?
- ✅ **Type usage**: Correct types enabling proper merging behavior?
- ✅ **Submodules**: Used appropriately for complex structures?
- ✅ **Priority system**: mkDefault used for overridable defaults?
- ✅ **Conditional configuration**: mkIf used correctly (not `mkIf condition true`)?
- ✅ **Cross-module communication**: Proper use of config argument?
- ✅ **Assertions**: Configuration validated with helpful messages?
- ✅ **Option descriptions**: Comprehensive documentation provided?

#### Package Writing Review
- ✅ **Derivation structure**: Follows stdenv.mkDerivation patterns?
- ✅ **strictDeps**: Enabled for cross-compilation support?
- ✅ **Input categorization**: nativeBuildInputs vs buildInputs correct?
- ✅ **Meta attributes**: Comprehensive metadata (description, license, maintainers)?
- ✅ **Phase hooks**: runHook preInstall/postInstall included?
- ✅ **Override support**: Package supports overrideAttrs?
- ✅ **Multi-output**: Large packages split appropriately?

#### Security Review
- ✅ **Systemd hardening**: DynamicUser, ProtectSystem, PrivateTmp?
- ✅ **Service isolation**: Minimal privileges and capabilities?
- ✅ **Secret management**: Runtime loading only (passwordFile patterns)?
- ✅ **Firewall configuration**: Minimal ports, interface-specific rules?

#### Performance Review
- ✅ **Lazy evaluation**: No unnecessary eager evaluation?
- ✅ **No IFD**: Import From Derivation avoided?
- ✅ **Proper dependencies**: Dependencies correctly specified?

### Step 4: Anti-Pattern Detection

**Check Against NIXOS-ANTI-PATTERNS.md:**

#### Language Anti-Patterns
- ❌ **mkIf true pattern**: `mkIf condition true` (use direct assignment)
- ❌ **Unquoted URLs**: All URLs properly quoted?
- ❌ **Excessive with**: Variable origins clear?
- ❌ **Dangerous rec**: Infinite recursion risks?
- ❌ **Import From Derivation**: Evaluation-time builds?
- ❌ **Incorrect types**: Wrong type preventing composition?
- ❌ **Config confusion**: Misunderstanding config argument vs attribute?

#### Security Anti-Patterns
- ❌ **Secrets during evaluation**: builtins.readFile on secrets?
- ❌ **Root services**: Services running without DynamicUser?
- ❌ **Disabled firewall**: Firewall disabled or all ports open?
- ❌ **Poor systemd security**: Missing hardening directives?

#### Package Writing Anti-Patterns
- ❌ **Missing strictDeps**: Cross-compilation broken?
- ❌ **Wrong input category**: Build tools in buildInputs?
- ❌ **Using override**: Should use overrideAttrs instead?
- ❌ **Missing meta**: No metadata for package discovery?
- ❌ **Missing phase hooks**: Custom phases without runHook?
- ❌ **Improper extend**: Using pkgs.extend for large changes?

#### Module System Anti-Patterns
- ❌ **No assertions**: Silent misconfiguration possible?
- ❌ **Ignoring priorities**: Hard-coded values instead of mkDefault?
- ❌ **Missing descriptions**: Options without documentation?

#### Architecture Anti-Patterns
- ❌ **Magic auto-discovery**: Hidden module loading?
- ❌ **Trivial wrappers**: Pointless function re-exports?
- ❌ **Code duplication**: Repeated code not extracted?
- ❌ **Monolithic files**: Should be split into modules?
- ❌ **Direct service config**: Services in configuration.nix instead of modules/?

### Step 5: Generate Structured Review Report

Provide output in this format:

```markdown
## Code Review Report

### Files Reviewed
- path/to/file1.nix
- path/to/file2.nix

### Summary
[Brief overview of the code quality and purpose]

---

## ✅ Strengths

### What's Done Well
1. **[Pattern/Aspect]**: [Specific example from code]
   - Why this is good: [Explanation]
   - Reference: [Section in PATTERNS.md]

2. **[Pattern/Aspect]**: [Specific example]
   ...

---

## ⚠️ Issues Found

### Critical Issues (Must Fix)
1. **[Anti-Pattern Name]** (Line XX)
   ```nix
   [Code snippet showing the issue]
   ```
   - **Problem**: [Clear explanation of why this is wrong]
   - **Fix**: [Specific solution with code example]
   - **Reference**: [Section in NIXOS-ANTI-PATTERNS.md]
   - **Impact**: [Security/Performance/Maintainability impact]

### Recommended Improvements (Should Fix)
1. **[Improvement Area]** (Line XX)
   ```nix
   [Code snippet]
   ```
   - **Suggestion**: [How to improve]
   - **Benefit**: [Why this matters]
   - **Reference**: [Section in PATTERNS.md]

### Minor Suggestions (Nice to Have)
1. **[Suggestion]** (Line XX)
   - [Brief description]

---

## 📋 Checklist Results

### Language & Syntax
- [x] No `mkIf condition true` patterns
- [x] URLs are quoted
- [ ] No excessive `with` usage ❌ (Found at line XX)
- [x] Using `inherit` appropriately
...

### Module System
- [x] Options have proper types
- [ ] Assertions validate configuration ⚠️ (Missing for option X)
- [x] mkDefault used for defaults
...

### Security & Safety
- [x] Secrets use runtime loading
- [x] Services run with minimal privileges
- [ ] Proper systemd hardening ❌ (Missing ProtectSystem at line XX)
...

### Package Writing (if applicable)
- [x] strictDeps enabled
- [x] Correct input categorization
- [ ] Missing meta.maintainers ⚠️
...

---

## 🔧 Recommended Actions

### Immediate (Before Merge)
1. Fix [Critical Issue 1]
2. Fix [Critical Issue 2]

### Short-term (This Week)
1. Implement [Recommended Improvement 1]
2. Add [Missing Feature]

### Long-term (Future Enhancement)
1. Consider [Architectural Improvement]

---

## 📚 References

Key documentation sections to review:
- PATTERNS.md: [Specific sections]
- NIXOS-ANTI-PATTERNS.md: [Specific sections]
- Official docs: [Relevant links]

---

## 💯 Overall Assessment

**Code Quality Score**: [X/10]

**Readability**: [Score/10] - [Brief comment]
**Security**: [Score/10] - [Brief comment]
**Performance**: [Score/10] - [Brief comment]
**Maintainability**: [Score/10] - [Brief comment]
**Best Practices Adherence**: [Score/10] - [Brief comment]

**Recommendation**: [APPROVE / APPROVE WITH CHANGES / NEEDS WORK]

**Summary**: [1-2 sentence overall assessment]
```

### Step 6: Provide Actionable Next Steps

After the review report, offer:

1. **Quick fixes**: Provide exact code snippets to replace problematic code
2. **Example implementations**: Show how to implement recommended improvements
3. **Testing guidance**: Suggest how to test the changes
4. **Documentation links**: Point to specific sections in PATTERNS.md or ANTI-PATTERNS.md

## Review Best Practices

1. **Be Constructive**: Focus on education, not criticism
2. **Be Specific**: Always reference line numbers and provide code examples
3. **Prioritize**: Separate critical issues from nice-to-haves
4. **Explain Why**: Always explain why something is an anti-pattern
5. **Provide Solutions**: Don't just identify problems, show how to fix them
6. **Reference Documentation**: Link to specific sections in PATTERNS.md or ANTI-PATTERNS.md
7. **Consider Context**: Understand the purpose before suggesting changes
8. **Check Thoroughly**: Review against the entire checklist in ANTI-PATTERNS.md

## Usage Examples

### Review specific file:
```
/review
Please review hosts/p620/configuration.nix
```

### Review recent changes:
```
/review
Please review all files I just committed
```

### Review staged changes:
```
/review
Please review my staged changes before I commit
```

### Deep review of module:
```
/review
Please do a comprehensive review of modules/services/myservice.nix focusing on security
```

### Review with specific focus:
```
/review
Review this configuration focusing on module system patterns and performance
```

## Important Notes

- **Always read the full files** - Don't make assumptions based on partial code
- **Check the complete checklist** - Use the comprehensive checklist from ANTI-PATTERNS.md
- **Provide examples** - Show correct code alongside identified issues
- **Be thorough** - This is meant to be a comprehensive, in-depth review
- **Follow the structure** - Use the report format consistently
- **Reference line numbers** - Always specify exact locations of issues

## After Review

Once the review is complete, offer to:
1. Create a summary document
2. Help implement the fixes
3. Re-review after changes are made
4. Explain any patterns or anti-patterns in more detail
