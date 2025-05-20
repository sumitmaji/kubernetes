// After OAuth login flow:
localStorage.setItem("id_token", idToken);

// For all API requests:
fetch("/send-command-batch", {
  method: "POST",
  headers: {
    "Authorization": "Bearer " + localStorage.getItem("id_token"),
    "Content-Type": "application/json"
  },
  body: JSON.stringify({ commands: ... })
})