const password = document.querySelector('#password');
const toggle = document.querySelector('#password-toggle');

if (password instanceof HTMLInputElement && toggle instanceof HTMLButtonElement) {
  toggle.addEventListener('click', () => {
    const show = password.type === 'password';
    password.type = show ? 'text' : 'password';
    toggle.textContent = show ? '隐藏' : '显示';
    toggle.setAttribute('aria-pressed', String(show));
    toggle.setAttribute('aria-label', show ? '隐藏密码' : '显示密码');
    password.focus({ preventScroll: true });
  });
}
