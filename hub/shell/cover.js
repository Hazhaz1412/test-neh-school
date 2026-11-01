const thought = document.getElementById('thought');
window.browser.onThought((line) => {
  thought.classList.toggle('on', Boolean(line));
  if (!line) return;
  thought.textContent = line.text;
  thought.dataset.kind = line.kind;
});
