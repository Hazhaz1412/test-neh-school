// The paired phone's page: it only keeps the channel open and says so. Later phone mechanics
// (motion, vibration) hook in here and send their fields through readPhone in phone.js.
const dot = document.getElementById('dot');
const state = document.getElementById('state');

function connect() {
  const socket = new WebSocket(location.href.replace(/^http/, 'ws'));
  socket.onopen = () => {
    dot.classList.add('on');
    state.textContent = 'Đã ghép với máy tính';
    socket.send(JSON.stringify({ report: 'đã ghép' }));
  };
  socket.onclose = () => {
    dot.classList.remove('on');
    state.textContent = 'Mất kết nối, đang thử lại…';
    setTimeout(connect, 1000);
  };
}

connect();
