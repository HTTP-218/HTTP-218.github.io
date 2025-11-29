const sidebar = document.getElementById("sidebar");
const openBtn = document.getElementById("menu-toggle");
const closeBtn = document.getElementById("menu-toggle-close");

if (openBtn) {
  openBtn.addEventListener("click", () => sidebar.classList.add("active"));
}

if (closeBtn) {
  closeBtn.addEventListener("click", () => sidebar.classList.remove("active"));
}
