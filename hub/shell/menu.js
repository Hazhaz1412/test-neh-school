window.browser.onState(({ profile }) => {
  document.body.dataset.theme = profile.theme;
  const avatar = document.getElementById('avatar');
  avatar.textContent = profile.initial;
  avatar.style.background = profile.color;
  document.getElementById('name').textContent = profile.name;
  document.getElementById('email').textContent = profile.email;
});
window.browser.ready();
