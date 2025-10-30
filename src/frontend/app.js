const apiBase = "/api";
const namesList = document.getElementById("namesList");
const addForm = document.getElementById("addForm");
const nameInput = document.getElementById("nameInput");
const addButton = document.getElementById("addButton");
const errorMessage = document.getElementById("errorMessage");
const successMessage = document.getElementById("successMessage");
const nameInputError = document.getElementById("nameInputError");

// Enhanced API request with better error handling
async function apiRequest(path, options = {}) {
  try {
    const res = await fetch(`${apiBase}${path}`, options);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const errorMsg = err.error || `Request failed with status ${res.status}`;
      throw new Error(errorMsg);
    }
    return res;
  } catch (e) {
    // Network errors or parsing errors
    if (e.name === 'TypeError' && e.message.includes('fetch')) {
      throw new Error('Unable to connect to server. Please check your connection.');
    }
    throw e;
  }
}

// Message display functions
function showError(message, temporary = true) {
  hideMessages();
  errorMessage.textContent = message;
  errorMessage.style.display = 'block';
  
  if (temporary) {
    setTimeout(() => {
      errorMessage.style.display = 'none';
    }, 5000);
  }
}

function showSuccess(message, temporary = true) {
  hideMessages();
  successMessage.textContent = message;
  successMessage.style.display = 'block';
  
  if (temporary) {
    setTimeout(() => {
      successMessage.style.display = 'none';
    }, 3000);
  }
}

function hideMessages() {
  errorMessage.style.display = 'none';
  successMessage.style.display = 'none';
}

// Loading state management
function setLoading(element, isLoading, originalText = '') {
  if (isLoading) {
    element.classList.add('loading');
    if (element.tagName === 'BUTTON') {
      element.innerHTML = '<span class="spinner"></span>Loading...';
      element.disabled = true;
    }
  } else {
    element.classList.remove('loading');
    if (element.tagName === 'BUTTON') {
      element.innerHTML = originalText;
      element.disabled = false;
    }
  }
}

// Input validation and error display
function validateNameInput(value) {
  clearFieldError('nameInput');
  
  if (!value || value.trim() === '') {
    showFieldError('nameInput', 'Name cannot be empty');
    return false;
  }
  
  if (value.trim().length > 50) {
    showFieldError('nameInput', 'Name cannot exceed 50 characters');
    return false;
  }
  
  if (value.trim() !== value) {
    // Auto-trim and show info
    nameInput.value = value.trim();
    showSuccess('Name was automatically trimmed', true);
  }
  
  return true;
}

function showFieldError(fieldId, message) {
  const field = document.getElementById(fieldId);
  const errorDiv = document.getElementById(fieldId + 'Error');
  
  field.classList.add('input-error');
  errorDiv.textContent = message;
  errorDiv.style.display = 'block';
}

function clearFieldError(fieldId) {
  const field = document.getElementById(fieldId);
  const errorDiv = document.getElementById(fieldId + 'Error');
  
  field.classList.remove('input-error');
  errorDiv.style.display = 'none';
}

async function loadNames() {
  try {
    setLoading(namesList, true);
    hideMessages();
    
    const res = await apiRequest("/names");
    const data = await res.json();
    
    namesList.innerHTML = "";

    if (data.names && data.names.length > 0) {
      data.names.forEach((item) => {
        const li = document.createElement("li");
        const timestamp = item.created_at ? new Date(item.created_at).toLocaleString() : 'N/A';
        li.innerHTML = `
          <div class="name-content">
            <span class="name">${escapeHtml(item.name)}</span>
            <span class="meta">${timestamp}</span>
          </div>
          <button onclick="deleteName(${item.id})" class="delete-btn">Delete</button>
        `;
        namesList.appendChild(li);
      });
      
      if (data.names.length === 1) {
        showSuccess('Found 1 name', true);
      } else {
        showSuccess(`Found ${data.names.length} names`, true);
      }
    } else {
      namesList.innerHTML = "<li><em>No names found</em></li>";
    }
  } catch (error) {
    showError(`Failed to load names: ${error.message}`);
    namesList.innerHTML = "<li><em>Error loading names</em></li>";
  } finally {
    setLoading(namesList, false);
  }
}



addForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  
  const name = nameInput.value.trim();
  const originalButtonText = addButton.innerHTML;
  
  // Validate input
  if (!validateNameInput(nameInput.value)) {
    return;
  }

  try {
    setLoading(addButton, true, originalButtonText);
    hideMessages();
    
    const res = await apiRequest("/names", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });

    nameInput.value = "";
    clearFieldError('nameInput');
    showSuccess(`Successfully added "${name}"`);
    
    // Reload the list to show the new name
    await loadNames();
    
  } catch (error) {
    if (error.message.includes('already exists')) {
      showFieldError('nameInput', 'This name already exists');
      showError(`Name "${name}" already exists in the list`);
    } else if (error.message.includes('too long')) {
      showFieldError('nameInput', 'Name is too long');
      showError('Name exceeds maximum length allowed');
    } else if (error.message.includes('empty')) {
      showFieldError('nameInput', 'Name cannot be empty');
      showError('Please enter a valid name');
    } else {
      showError(`Failed to add name: ${error.message}`);
    }
  } finally {
    setLoading(addButton, false, originalButtonText);
  }
});

async function deleteName(nameId) {
  try {
    hideMessages();
    
    // Get the name text from the DOM for the confirmation dialog
    const nameElement = event.target.closest('li').querySelector('.name');
    const nameText = nameElement ? nameElement.textContent : 'this name';
    
    // Show confirmation with better styling than default confirm()
    if (!confirm(`Are you sure you want to delete "${nameText}"?`)) {
      return;
    }
    
    const res = await apiRequest(`/names/${nameId}`, { 
      method: "DELETE" 
    });
    
    showSuccess(`Successfully deleted "${nameText}"`);
    await loadNames();
    
  } catch (error) {
    if (error.message.includes('not found')) {
      showError(`Name with ID ${nameId} was not found`);
    } else {
      showError(`Failed to delete name: ${error.message}`);
    }
    // Refresh the list in case it's out of sync
    await loadNames();
  }
}

// Utility function to escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Add input validation on typing
nameInput.addEventListener('input', function() {
  const value = this.value;
  
  // Clear previous field errors as user types
  if (value.trim().length > 0) {
    clearFieldError('nameInput');
  }
  
  // Show warning for length
  if (value.length > 45) {
    showFieldError('nameInput', `${50 - value.length} characters remaining`);
  }
});

// Initialize the application
loadNames();
