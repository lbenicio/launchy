/* Minimal JS for Launchy landing page */
document.addEventListener("DOMContentLoaded", () => {
	const subscribeForm = document.getElementById("subscribe-form");
	const emailInput = document.getElementById("email");
	const msg = document.getElementById("subscribe-msg");

	subscribeForm.addEventListener("submit", (e) => {
		e.preventDefault();
		const email = (emailInput.value || "").trim();
		if (!email || !/^\S+@\S+\.\S+$/.test(email)) {
			msg.textContent = "Please enter a valid email address.";
			msg.style.color = "#c63b3b";
			return;
		}

		// Fake submission — in real world we'd send to a server or use a service
		msg.style.color = "#0f5132";
		msg.textContent = "Thanks! You'll be notified about new releases.";
		subscribeForm.reset();

		// Add a small confetti style animation using CSS
		const confetti = document.createElement("div");
		confetti.className = "confetti";
		document.body.appendChild(confetti);
		setTimeout(() => confetti.remove(), 900);
	});

	// Add 'copy url' on click for brand
	const logo = document.querySelector(".logo");
	logo &&
		logo.addEventListener("click", async (e) => {
			e.preventDefault();
			try {
				await navigator.clipboard.writeText("https://launchy.website");
				const old = logo.textContent;
				logo.textContent = "Copied!";
				setTimeout(() => (logo.textContent = old), 1100);
			} catch (err) {
				// No-op
			}
		});
});
