# Manual Testing Checklist

This document provides comprehensive manual testing procedures for the Names Manager application. Follow these step-by-step instructions to verify all functionality works correctly.

## Prerequisites

### Environment Setup
- [ ] Docker and Docker Compose installed
- [ ] Application running: `cd src && docker compose up -d`
- [ ] Frontend accessible at: http://localhost:8080
- [ ] Backend API accessible at: http://localhost:8080/api/*

### Test Data Preparation
- [ ] Start with clean database (fresh container start)
- [ ] Browser opened to http://localhost:8080
- [ ] Browser developer tools accessible (F12)
- [ ] Terminal/command line ready for API testing

---

## 1. Basic Application Health Tests

### 1.1 Application Startup
**Objective**: Verify application starts correctly

**Steps**:
1. Navigate to http://localhost:8080
2. Verify page loads without errors
3. Check browser console for JavaScript errors
4. Verify page displays "Names Manager" title

**Expected Results**:
- [ ] Page loads within 3 seconds
- [ ] No browser console errors
- [ ] Form with "Name" input field visible
- [ ] "Add Name" button visible
- [ ] Empty list message displayed (if no names)

### 1.2 Health Check Endpoints
**Objective**: Verify monitoring endpoints work

**Steps**:
1. Test basic health: `curl http://localhost:8080/api/health`
2. Test database health: `curl http://localhost:8080/api/health/db`

**Expected Results**:
- [ ] Basic health returns 200 status with `"status": "healthy"`
- [ ] Database health returns 200 status with `"database": "connected"`
- [ ] Responses are valid JSON format
- [ ] Timestamps are present and recent

---

## 2. Core Functionality Tests

### 2.1 Add Names - Happy Path
**Objective**: Test normal name addition workflow

**Test Cases**:

**Test 2.1.1: Simple Name**
1. Enter "John Doe" in the name field
2. Click "Add Name" button
3. Observe the results

**Expected Results**:
- [ ] Success message appears: "Successfully added 'John Doe'"
- [ ] Name appears in the list
- [ ] Input field is cleared
- [ ] No error messages shown

**Test 2.1.2: International Characters**
1. Enter "José García-López" in the name field
2. Click "Add Name" button
3. Verify name displays correctly

**Expected Results**:
- [ ] Name added successfully
- [ ] International characters display correctly
- [ ] No character encoding issues

**Test 2.1.3: Names with Special Characters**
1. Enter "O'Connor & Associates" in the name field
2. Click "Add Name" button
3. Verify handling of apostrophes and ampersands

**Expected Results**:
- [ ] Name added successfully
- [ ] Special characters may be HTML-escaped for security
- [ ] Display is readable and correct

### 2.2 Add Names - Input Validation
**Objective**: Test input validation and error handling

**Test 2.2.1: Empty Name**
1. Leave name field empty
2. Click "Add Name" button

**Expected Results**:
- [ ] Error message: "Please enter a valid name"
- [ ] No name added to list
- [ ] Form remains active for retry

**Test 2.2.2: Whitespace Only**
1. Enter only spaces: "   "
2. Click "Add Name" button

**Expected Results**:
- [ ] Error message about empty name
- [ ] No name added to list

**Test 2.2.3: Long Name**
1. Enter a name longer than 50 characters: "This is a very long name that exceeds the maximum length limit"
2. Click "Add Name" button

**Expected Results**:
- [ ] Error message about length limit
- [ ] Character counter shows over limit (if implemented)
- [ ] No name added to list

**Test 2.2.4: Duplicate Name**
1. Add "John Doe" successfully
2. Try to add "John Doe" again
3. Observe behavior

**Expected Results**:
- [ ] Error message about duplicate name (if implemented)
- [ ] OR second entry allowed with different ID

### 2.3 Security - XSS Prevention
**Objective**: Verify XSS attacks are properly prevented

**Test 2.3.1: Script Tag Injection**
1. Enter: `<script>alert('XSS')</script>`
2. Click "Add Name" button
3. Verify no JavaScript executes

**Expected Results**:
- [ ] No alert popup appears
- [ ] Name is added with escaped HTML: `&lt;script&gt;alert('XSS')&lt;/script&gt;`
- [ ] Text displays safely in the list

**Test 2.3.2: Event Handler Injection**
1. Enter: `<img src=x onerror=alert('hack')>`
2. Click "Add Name" button
3. Verify no JavaScript executes

**Expected Results**:
- [ ] No alert popup appears
- [ ] HTML is escaped and safe
- [ ] No image loading errors

**Test 2.3.3: Complex XSS Attempt**
1. Enter: `<svg onload=alert('xss')><script>fetch('/api/names')</script>`
2. Click "Add Name" button

**Expected Results**:
- [ ] No JavaScript execution
- [ ] All HTML tags properly escaped
- [ ] Content displays as harmless text

### 2.4 View Names
**Objective**: Test name listing functionality

**Test 2.4.1: Empty List**
1. Start with clean database
2. Load the page

**Expected Results**:
- [ ] "No names found" or similar message displayed
- [ ] No JavaScript errors
- [ ] Form still functional

**Test 2.4.2: Single Name**
1. Add one name
2. Verify display

**Expected Results**:
- [ ] Name appears in list
- [ ] Delete button present for the name
- [ ] List formatting correct

**Test 2.4.3: Multiple Names**
1. Add 5 different names
2. Verify all display correctly

**Expected Results**:
- [ ] All names appear in list
- [ ] Each has a delete button
- [ ] Order is consistent (newest first or alphabetical)

### 2.5 Delete Names
**Objective**: Test name deletion functionality

**Test 2.5.1: Delete Single Name**
1. Add "Test Name"
2. Click delete button for "Test Name"
3. Confirm deletion if prompted

**Expected Results**:
- [ ] Confirmation dialog appears (if implemented)
- [ ] Name is removed from list
- [ ] Success message appears
- [ ] List updates correctly

**Test 2.5.2: Delete from Multiple Names**
1. Add 3 names: "Alice", "Bob", "Charlie"
2. Delete "Bob"
3. Verify remaining names

**Expected Results**:
- [ ] Only "Bob" is removed
- [ ] "Alice" and "Charlie" remain
- [ ] List order maintained

**Test 2.5.3: Delete Last Name**
1. Add one name
2. Delete that name
3. Verify empty state

**Expected Results**:
- [ ] Name is removed
- [ ] "No names found" message appears
- [ ] Add functionality still works

---

## 3. API Testing

### 3.1 Direct API Tests
**Objective**: Test API endpoints directly

**Test 3.1.1: GET Names**
```bash
curl -X GET http://localhost:8080/api/names
```
**Expected Results**:
- [ ] Returns JSON array
- [ ] Status code 200
- [ ] Each name has id, name, created_at fields

**Test 3.1.2: POST New Name**
```bash
curl -X POST http://localhost:8080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name": "API Test Name"}'
```
**Expected Results**:
- [ ] Returns JSON with new name data
- [ ] Status code 200
- [ ] Response includes generated ID

**Test 3.1.3: DELETE Name**
```bash
# First get a name ID, then:
curl -X DELETE http://localhost:8080/api/names/[ID]
```
**Expected Results**:
- [ ] Status code 200
- [ ] Confirmation message returned
- [ ] Name no longer appears in GET request

### 3.2 API Error Handling
**Objective**: Test API error responses

**Test 3.2.1: Invalid JSON**
```bash
curl -X POST http://localhost:8080/api/names \
  -H "Content-Type: application/json" \
  -d '{"name": invalid json}'
```
**Expected Results**:
- [ ] Status code 400
- [ ] Error message about invalid JSON

**Test 3.2.2: Missing Name Field**
```bash
curl -X POST http://localhost:8080/api/names \
  -H "Content-Type: application/json" \
  -d '{}'
```
**Expected Results**:
- [ ] Status code 400
- [ ] Error message about missing name

**Test 3.2.3: Delete Non-existent Name**
```bash
curl -X DELETE http://localhost:8080/api/names/99999
```
**Expected Results**:
- [ ] Status code 404
- [ ] Error message about name not found

---

## 4. Frontend Error Handling

### 4.1 Network Error Simulation
**Objective**: Test frontend behavior when API is unavailable

**Test 4.1.1: Server Down**
1. Stop the backend: `docker compose stop backend`
2. Try to add a name in the frontend
3. Try to load the page

**Expected Results**:
- [ ] User-friendly error message displayed
- [ ] No JavaScript console errors
- [ ] Form doesn't break or freeze

**Test 4.1.2: Server Recovery**
1. Restart backend: `docker compose start backend`
2. Try frontend operations again

**Expected Results**:
- [ ] Functionality resumes normally
- [ ] No page refresh required
- [ ] Previous state maintained if possible

### 4.2 UI Feedback
**Objective**: Test user interface feedback

**Test 4.2.1: Loading States**
1. Add a name and observe button behavior
2. Check for loading indicators

**Expected Results**:
- [ ] Button shows loading state during API call
- [ ] Button is disabled during submission
- [ ] Loading completes when operation finishes

**Test 4.2.2: Success Messages**
1. Add a name successfully
2. Observe success feedback

**Expected Results**:
- [ ] Success message appears
- [ ] Message is clearly visible
- [ ] Message disappears after reasonable time

**Test 4.2.3: Error Messages**
1. Trigger various errors (empty name, long name, etc.)
2. Observe error feedback

**Expected Results**:
- [ ] Error messages are specific and helpful
- [ ] Messages appear in consistent location
- [ ] Messages are styled distinctly from success messages

---

## 5. Browser Compatibility

### 5.1 Cross-Browser Testing
**Objective**: Verify functionality across browsers

**Test in each browser**:
- Chrome/Chromium
- Firefox  
- Safari (macOS)
- Edge (Windows)

**For each browser, verify**:
- [ ] Page loads correctly
- [ ] Add name functionality works
- [ ] Delete name functionality works
- [ ] CSS styling appears correct
- [ ] JavaScript executes without errors

### 5.2 Mobile Responsiveness
**Objective**: Test mobile device compatibility

**Test 5.2.1: Mobile Browser**
1. Open in mobile browser or browser developer tools mobile mode
2. Test all functionality

**Expected Results**:
- [ ] Page is readable on small screens
- [ ] Buttons are clickable on touch devices
- [ ] Form fields are appropriately sized
- [ ] No horizontal scrolling required

---

## 6. Performance Testing

### 6.1 Load Testing
**Objective**: Test with multiple names

**Test 6.1.1: Many Names**
1. Add 50+ names to the database
2. Load the frontend page
3. Test add/delete operations

**Expected Results**:
- [ ] Page loads within reasonable time (< 5 seconds)
- [ ] List scrolls smoothly
- [ ] Operations remain responsive

### 6.2 Network Performance
**Objective**: Test on slow connections

**Test 6.2.1: Slow Network Simulation**
1. Use browser dev tools to simulate slow 3G
2. Test add/delete operations

**Expected Results**:
- [ ] Loading states appear appropriately
- [ ] Operations complete successfully
- [ ] No timeout errors

---

## 7. Data Persistence

### 7.1 Data Survival Tests
**Objective**: Verify data persists correctly

**Test 7.1.1: Container Restart**
1. Add several names
2. Restart containers: `docker compose restart`
3. Verify data is still present

**Expected Results**:
- [ ] All names still appear after restart
- [ ] No data loss occurred
- [ ] Application functions normally

**Test 7.1.2: Browser Refresh**
1. Add names in browser
2. Refresh the page (F5)
3. Verify names still appear

**Expected Results**:
- [ ] Names persist after refresh
- [ ] Page state reconstructed correctly

---

## 8. Security Testing

### 8.1 Input Sanitization
**Objective**: Comprehensive XSS prevention testing

**Test various payloads**:
1. `<script>alert(1)</script>`
2. `javascript:alert(1)`
3. `<img src=x onerror=alert(1)>`
4. `<svg onload=alert(1)>`
5. `"><script>alert(1)</script>`
6. `';alert(1);//`

**For each payload**:
- [ ] No JavaScript execution occurs
- [ ] Content is safely escaped
- [ ] Display shows harmless text

### 8.2 API Security
**Objective**: Test API security measures

**Test 8.2.1: Content-Type Validation**
```bash
curl -X POST http://localhost:8080/api/names \
  -d '{"name": "test"}'
```
**Expected Results**:
- [ ] Request rejected due to missing Content-Type
- [ ] Appropriate error message

**Test 8.2.2: Method Validation**
```bash
curl -X PUT http://localhost:8080/api/names
```
**Expected Results**:
- [ ] Method not allowed error (405)
- [ ] Appropriate error response

---

## 9. Configuration Testing

### 9.1 Environment Variables
**Objective**: Test configuration flexibility

**Test 9.1.1: Name Length Configuration**
1. Modify `MAX_NAME_LENGTH` in `.env`
2. Restart application
3. Test with names at the new limit

**Expected Results**:
- [ ] New length limit is enforced
- [ ] Error messages reflect new limit
- [ ] Application adapts to configuration

### 9.2 Logging Configuration
**Objective**: Test logging system

**Test 9.2.1: Log Level Changes**
1. Set `LOG_LEVEL=DEBUG` in `.env`
2. Restart application
3. Check logs for increased verbosity

**Expected Results**:
- [ ] More detailed logs appear
- [ ] Log format is consistent
- [ ] No performance degradation

---

## 10. Deployment Testing

### 10.1 Fresh Deployment
**Objective**: Test complete deployment process

**Test 10.1.1: Clean Installation**
1. Remove all containers: `docker compose down -v`
2. Start fresh: `docker compose up -d`
3. Test all functionality

**Expected Results**:
- [ ] Database initializes correctly
- [ ] Application starts without errors
- [ ] All functionality works immediately

---

## Test Report Template

After completing tests, document results:

### Test Summary
- **Date**: [Date of testing]
- **Tester**: [Your name]
- **Environment**: [Docker version, OS, Browser versions]
- **Duration**: [Time taken]

### Results
- **Total Tests**: [Number]
- **Passed**: [Number]
- **Failed**: [Number]
- **Skipped**: [Number]

### Failed Tests
List any failed tests with details:
1. **Test**: [Test name]
   **Issue**: [What went wrong]
   **Impact**: [Severity]
   **Notes**: [Additional information]

### Recommendations
- [ ] All tests passed - Ready for production
- [ ] Minor issues found - Can deploy with notes
- [ ] Major issues found - Do not deploy

### Additional Notes
[Any other observations or recommendations]

---

## Troubleshooting

### Common Issues

**Page doesn't load**:
- Check containers are running: `docker compose ps`
- Check ports aren't in use: `lsof -i :8080`
- Check browser console for errors

**API calls fail**:
- Verify backend container is healthy
- Check network connectivity
- Verify API endpoints with curl

**Database issues**:
- Check database container logs: `docker compose logs db`
- Verify database connection in health check
- Check data persistence with database restart

**Frontend errors**:
- Check browser console (F12)
- Verify JavaScript files load correctly
- Test with different browsers

This testing checklist ensures comprehensive coverage of all application functionality, security measures, and edge cases.