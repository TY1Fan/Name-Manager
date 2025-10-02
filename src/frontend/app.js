const apiBase = "/api";
const namesList = document.getElementById("namesList");
const addForm = document.getElementById("addForm");
const nameInput = document.getElementById("nameInput");

async function apiRequest(path, options = {}) {
  try {
    const res = await fetch(`${apiBase}${path}`, options);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Request failed: ${res.status}`);
    }
    return res;
  } catch (e) {
    alert(`Error: ${e.message}`);
    return null;
  }
}

async function fetchNames() {
  const res = await apiRequest("/names");
  if (!res) return;
  const data = await res.json();
  renderList(data);
}

function renderList(items) {
  namesList.innerHTML = "";

  if (!items || items.length === 0) {
    namesList.innerHTML = "<li>Add names to view now.</li>";
    return;
  }

  namesList.innerHTML = items.map(item => `
    <li>
      <div>
        <span class="name">${item.name}</span>
        ${item.created_at ? `<span class="meta"> • Added on: ${new Date(item.created_at).toLocaleString()}</span>` : ""}
      </div>
      <button onclick="deleteName(${item.id})">Delete</button>
    </li>
  `).join("");
}

addForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const name = nameInput.value.trim();

  if (!name || name.length > 50) {
    alert("Invalid: Name should be between 1-50 characters.");
    return;
  }

  const res = await apiRequest("/names", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name })
  });

  if (res) {
    nameInput.value = "";
    fetchNames();
  }
});

async function deleteName(id) {
  if (!confirm("Delete this name?")) return;
  const res = await apiRequest(`/names/${id}`, { method: "DELETE" });
  if (res) fetchNames();
}

fetchNames();
