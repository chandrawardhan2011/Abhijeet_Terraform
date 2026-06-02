/* Wires each card's form to the dispatcher. On submit, fetch with the
   form's data + the vuln name, then render the returned HTML fragment
   into the card's .out container. */

document.querySelectorAll('form[data-endpoint]').forEach((form) => {
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const vuln = form.dataset.endpoint;
    const out = form.parentElement.querySelector('.out');

    const params = new URLSearchParams();
    params.set('vuln', vuln);
    for (const [k, v] of new FormData(form)) params.set(k, v);

    out.innerHTML = '<div class="result empty">…</div>';
    try {
      const res = await fetch('/index.php?' + params.toString());
      out.innerHTML = await res.text();
    } catch (err) {
      out.innerHTML = '<div class="result error">request failed: ' + err.message + '</div>';
    }
  });
});
