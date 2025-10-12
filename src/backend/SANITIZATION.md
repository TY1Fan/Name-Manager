# Input Sanitization Documentation

The Names Manager API implements comprehensive input sanitization to prevent XSS (Cross-Site Scripting) attacks and ensure data integrity.

## Features

### HTML Escaping
All user input is automatically HTML-escaped to prevent malicious code execution:

- `<script>` tags → `&lt;script&gt;` (safe for display)
- Event handlers → `onclick=` → `onclick=` (attributes escaped)
- Special characters → `&`, `<`, `>`, `"`, `'` are properly encoded

### Content Normalization
Input is normalized for consistency and safety:

- **Whitespace normalization**: Multiple spaces reduced to single spaces
- **Trimming**: Leading/trailing whitespace removed
- **Null byte removal**: Binary null characters (`\x00`) removed

### Security Logging
All sanitization operations are logged for security monitoring:

```
WARNING - Input sanitization applied: '<script>alert(1)</script>' -> '&lt;script&gt;alert(1)&lt;/script&gt;'
```

## Implementation

### Core Functions

**`sanitize_input(text: str) -> str:`**
- Primary sanitization function
- Uses Python's `html.escape()` for HTML entity encoding
- Removes dangerous characters and normalizes whitespace

**`validation(name: str) -> tuple:`**
- Enhanced validation with integrated sanitization
- Returns `(is_valid: bool, result: str)`
- Applies sanitization before length and emptiness checks

### Security Measures

1. **XSS Prevention**: All HTML/JavaScript code is escaped
2. **Data Integrity**: Input normalized consistently
3. **Audit Trail**: Security events logged for monitoring
4. **Graceful Handling**: Invalid input handled without errors

## Examples

### Malicious Input Handling
```python
# Input:  "<script>alert('xss')</script>"
# Output: "&lt;script&gt;alert('xss')&lt;/script&gt;"
# Safe for HTML display, cannot execute
```

### Normal Input Preservation
```python
# Input:  "John Doe"
# Output: "John Doe"
# Unchanged for normal text
```

### Special Characters
```python
# Input:  "O'Connor & Smith"
# Output: "O&#x27;Connor &amp; Smith"
# Apostrophes and ampersands safely encoded
```

### Whitespace Normalization
```python
# Input:  "  Multiple   spaces  "
# Output: "Multiple spaces"
# Normalized to single spaces, trimmed
```

## Integration

### Frontend Display
The frontend safely displays sanitized content using the escaped HTML entities:

```javascript
// Server returns: "&lt;script&gt;alert(1)&lt;/script&gt;"
// Browser displays: "<script>alert(1)</script>" (as text, not code)
// No JavaScript execution occurs
```

### Database Storage
Sanitized content is stored in the database, ensuring:
- Consistent data format
- Safe retrieval and display
- No executable code in storage

## Testing

Sanitization is verified through:
- Manual functional testing with malicious inputs
- Integration testing with the full application stack
- Validation that normal use cases continue to work

Common test scenarios:
- Script tag injection attempts
- Event handler injection (onclick, onerror, etc.)
- Special character handling
- Unicode text preservation
- Whitespace edge cases

## Performance Impact

- **Minimal overhead**: HTML escaping is a fast operation
- **Memory efficient**: In-place string processing where possible
- **Scalable**: No significant impact on API response times

## Security Benefits

1. **XSS Prevention**: Malicious scripts cannot execute
2. **Data Consistency**: All input normalized to same format
3. **Audit Capability**: Security events are logged
4. **Defense in Depth**: Multiple layers of protection
5. **Backward Compatibility**: Existing functionality preserved