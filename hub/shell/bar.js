const address = document.getElementById('address');
const back = document.getElementById('back');
const forward = document.getElementById('forward');
const strip = document.getElementById('tabs');

document.getElementById('bar').addEventListener('submit', (event) => {
  event.preventDefault();
  window.browser.go(address.value);
  address.blur();
});
address.addEventListener('focus', () => address.select());
back.addEventListener('click', () => window.browser.nav('back'));
forward.addEventListener('click', () => window.browser.nav('forward'));
document.getElementById('reload').addEventListener('click', () => window.browser.nav('reload'));
document.getElementById('new-tab').addEventListener('click', () => window.browser.tab('new'));
for (const action of ['minimize', 'maximize', 'close']) {
  document.getElementById(action).addEventListener('click', () => window.browser.windowAction(action));
}
document.getElementById('star').addEventListener('click', () => window.browser.toggleBookmark());
document.getElementById('avatar').addEventListener('click', () => window.browser.toggleMenu());
window.browser.onFocusAddress(() => address.focus());

function tabElement(tab) {
  const element = document.createElement('div');
  element.className = `tab${tab.active ? ' active' : ''}`;
  element.addEventListener('mousedown', () => window.browser.tab('select', tab.id));
  const icon = document.createElement('span');
  icon.className = tab.loading ? 'favicon loading' : 'favicon';
  const title = document.createElement('span');
  title.className = 'title';
  title.textContent = tab.title;
  const close = document.createElement('button');
  close.className = 'close';
  close.textContent = '×';
  close.addEventListener('mousedown', (event) => event.stopPropagation());
  close.addEventListener('click', () => window.browser.tab('close', tab.id));
  element.append(icon, title, close);
  return element;
}

function bookmarkElement({ title, url }) {
  const link = document.createElement('a');
  const icon = document.createElement('span');
  icon.className = 'favicon';
  link.append(icon, title);
  link.addEventListener('click', () => window.browser.go(url));
  return link;
}

window.browser.onState((state) => {
  if (document.activeElement !== address) address.value = decodeURI(state.url).replace(/^https:\/\//, '').replace(/\/$/, '');
  document.body.dataset.theme = state.profile.theme;
  document.getElementById('lock').classList.toggle('hidden', !state.url);
  back.disabled = !state.canBack;
  forward.disabled = !state.canForward;
  const star = document.getElementById('star');
  star.disabled = !state.url || state.visiting;
  star.classList.toggle('on', state.bookmarked);
  const avatar = document.getElementById('avatar');
  avatar.textContent = state.profile.initial;
  avatar.style.background = state.profile.color;
  strip.replaceChildren(...state.tabs.map(tabElement));
  document.getElementById('bookmarks').replaceChildren(...state.bookmarks.map(bookmarkElement));
});
window.browser.ready();
