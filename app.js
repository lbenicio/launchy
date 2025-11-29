/* Minimal JS for Launchy landing page */
document.addEventListener("DOMContentLoaded", () => {
	const subscribeForm = document.getElementById("subscribe-form");
	const emailInput = document.getElementById("email");
	const msg = document.getElementById("subscribe-msg");

	// Only wire up the form if present
	if (subscribeForm) {
		// Keep compatibility with the existing 'subscribe-form' styles
		const submitBtn = subscribeForm.querySelector("[type=submit]");

		// Attempt to fetch a nonce for listmonk if the form expects it.
		(async () => {
			try {
				const nonceInput = subscribeForm.querySelector('[name="nonce"]');
				if (nonceInput && !nonceInput.value) {
					// Try to GET the form action and search for a nonce input (best-effort; may be blocked by CORS)
					const actionUrl = subscribeForm.getAttribute("action");
					if (actionUrl) {
						try {
							const res = await fetch(actionUrl, { method: "GET", mode: "cors" });
							if (res && res.ok) {
								const text = await res.text();
								const match = text.match(/name=(?:"|')nonce(?:"|')\s+value=(?:"|')([^"']+)(?:"|')/i);
								if (match && match[1]) {
									nonceInput.value = match[1];
								}
							}
						} catch (err) {
							// Ignore CORS or network errors — we have fallback behavior on submission
						}
					}
				}
			} catch (err) {
				// No-op; graceful degradation
			}
		})();

		subscribeForm.addEventListener("submit", async (e) => {
			e.preventDefault();

			if (!emailInput) return;
			const email = (emailInput.value || "").trim();
			if (!email || !/^\S+@\S+\.\S+$/.test(email)) {
				msg.textContent = "Please enter a valid email address.";
				msg.style.color = "#c63b3b";
				return;
			}

			const action = subscribeForm.getAttribute("action");
			const fd = new FormData(subscribeForm);

			// Disable submit while posting
			if (submitBtn) {
				const orig = submitBtn.value || submitBtn.textContent || "Subscribe";
				submitBtn.disabled = true;
				submitBtn.dataset.orig = orig;
				if (submitBtn.tagName.toLowerCase() === "input") {
					submitBtn.value = "Subscribing…";
				} else {
					submitBtn.textContent = "Subscribing…";
				}
			}

			try {
				// Try AJAX submission — this works when the endpoint supports CORS
				const res = await fetch(action, {
					method: "POST",
					body: fd,
					mode: "cors",
					credentials: "omit",
				});

				if (res.ok) {
					msg.style.color = "#0f5132";
					msg.textContent = "Thanks! You'll be notified about new releases.";
					subscribeForm.reset();

					// Add a small confetti style animation using CSS
					const confetti = document.createElement("div");
					confetti.className = "confetti";
					document.body.appendChild(confetti);
					setTimeout(() => confetti.remove(), 900);
				} else {
					// If non-2xx, try to read body for friendly messages
					const text = await res.text();
					// Heuristic: treat redirect or 200-like text as success; otherwise show error
					if (text && (text.toLowerCase().includes("success") || text.toLowerCase().includes("thank"))) {
						msg.style.color = "#0f5132";
						msg.textContent = "Thanks! You'll be notified about new releases.";
						subscribeForm.reset();
						const confetti = document.createElement("div");
						confetti.className = "confetti";
						document.body.appendChild(confetti);
						setTimeout(() => confetti.remove(), 900);
					} else {
						throw new Error(`Subscription failed: ${res.status}`);
					}
				}
			} catch (err) {
				// If AJAX failed (CORS or network), attempt a traditional HTML form submit as a fallback.
				try {
					msg.style.color = "#0f5132";
					msg.textContent = "Attempting to submit — you may be redirected to a confirmation page.";
					// submit will perform a traditional navigation if the endpoint expects it
					subscribeForm.submit();
				} catch (err2) {
					msg.textContent = "Subscription failed. Please try again later.";
					msg.style.color = "#c63b3b";
				}
			} finally {
				if (submitBtn) {
					submitBtn.disabled = false;
					if (submitBtn.tagName.toLowerCase() === "input") {
						submitBtn.value = submitBtn.dataset.orig || "Subscribe";
					} else {
						submitBtn.textContent = submitBtn.dataset.orig || "Subscribe";
					}
				}
			}
		});
	}

	// Add 'copy url' on click for brand and open repo in new tab
	const logo = document.querySelector(".logo");
	if (logo) {
		logo.addEventListener("click", async (e) => {
			e.preventDefault();
			const href = logo.href || "https://github.com/lbenicio/launchy";
			try {
				await navigator.clipboard.writeText(href);
				const old = logo.textContent;
				logo.textContent = "Copied!";
				setTimeout(() => (logo.textContent = old), 1100);
			} catch (err) {
				// No-op — still open the link
			}
			// Open the repo (allowing the default to open would trigger navigation; we do it programmatically so we can show 'Copied!')
			setTimeout(() => window.open(href, "_blank"), 350);
		});
	}
});
