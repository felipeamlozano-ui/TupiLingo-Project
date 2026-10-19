/**
 * TupiLingo • Landing Page Interactions & Advanced Animations
 * Mobile-First, Accessible, Native Dialogs, 3D Hero Parallax & Scroll Reveal
 */

document.addEventListener('DOMContentLoaded', () => {
  initHeaderScroll();
  initMobileMenu();
  initHeroTilt();
  initScrollReveal();
  initShowcaseTabs();
  initAccordion();
  initFeedbackModal();
  initCopyLink();
  detectAndroidDevice();
});

/**
 * 1. Cabeçalho com Efeito de Compactação e Blur ao Rolar
 */
function initHeaderScroll() {
  const header = document.getElementById('siteHeader');
  if (!header) return;

  const onScroll = () => {
    if (window.scrollY > 25) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }
  };

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

/**
 * 2. Menu Mobile Responsivo e Acessível
 */
function initMobileMenu() {
  const toggleBtn = document.getElementById('mobileMenuToggle');
  const navLinks = document.getElementById('navLinks');

  if (!toggleBtn || !navLinks) return;

  const toggleMenu = () => {
    const isOpen = navLinks.classList.contains('open');
    if (isOpen) {
      navLinks.classList.remove('open');
      toggleBtn.classList.remove('active');
      toggleBtn.setAttribute('aria-expanded', 'false');
    } else {
      navLinks.classList.add('open');
      toggleBtn.classList.add('active');
      toggleBtn.setAttribute('aria-expanded', 'true');
    }
  };

  toggleBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    toggleMenu();
  });

  // Fechar ao clicar em qualquer link
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      toggleBtn.classList.remove('active');
      toggleBtn.setAttribute('aria-expanded', 'false');
    });
  });

  // Fechar ao clicar fora
  document.addEventListener('click', (e) => {
    if (!navLinks.contains(e.target) && !toggleBtn.contains(e.target)) {
      navLinks.classList.remove('open');
      toggleBtn.classList.remove('active');
      toggleBtn.setAttribute('aria-expanded', 'false');
    }
  });
}

/**
 * 3. Parallax e Tilt 3D Interativo no Celular Principal do Hero
 */
function initHeroTilt() {
  const heroVisual = document.getElementById('heroVisual');
  const heroPhone = document.getElementById('heroPhoneFrame');

  if (!heroVisual || !heroPhone) return;

  // Habilita apenas em dispositivos com ponteiro fino (Desktop / Mouse)
  const isFinePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  if (!isFinePointer) return;

  let bounds = heroVisual.getBoundingClientRect();
  let isHovered = false;

  window.addEventListener('resize', () => {
    bounds = heroVisual.getBoundingClientRect();
  });

  heroVisual.addEventListener('mouseenter', () => {
    isHovered = true;
    bounds = heroVisual.getBoundingClientRect();
  });

  heroVisual.addEventListener('mousemove', (e) => {
    if (!isHovered) return;

    const x = e.clientX - bounds.left;
    const y = e.clientY - bounds.top;

    const xPercent = (x / bounds.width - 0.5) * 2; // -1 a 1
    const yPercent = (y / bounds.height - 0.5) * 2; // -1 a 1

    const tiltX = -yPercent * 10; // Inclina para cima/baixo
    const tiltY = xPercent * 12;  // Inclina para esquerda/direita

    heroPhone.style.transform = `perspective(1000px) rotateX(${tiltX.toFixed(2)}deg) rotateY(${tiltY.toFixed(2)}deg) translateY(-8px)`;
  });

  heroVisual.addEventListener('mouseleave', () => {
    isHovered = false;
    heroPhone.style.transform = '';
  });
}

/**
 * 4. Sistema de Revelação ao Rolar a Página (Scroll Reveal)
 */
function initScrollReveal() {
  const revealElements = document.querySelectorAll('.reveal-on-scroll');
  if (!revealElements.length) return;

  if (!('IntersectionObserver' in window)) {
    revealElements.forEach(el => el.classList.add('is-revealed'));
    return;
  }

  const observer = new IntersectionObserver((entries, obs) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-revealed');
        obs.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12,
    rootMargin: '0px 0px -40px 0px'
  });

  revealElements.forEach(el => observer.observe(el));
}

/**
 * 5. Filtro de Abas e Transição do Showcase
 */
function initShowcaseTabs() {
  const tabButtons = document.querySelectorAll('.tab-btn');
  const showcaseCards = document.querySelectorAll('.showcase-card');

  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetCategory = btn.dataset.category;

      // Atualiza estado ativo
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      // Filtra os cards com animação suave
      showcaseCards.forEach(card => {
        if (targetCategory === 'all' || card.dataset.category === targetCategory) {
          card.style.display = 'flex';
          card.style.animation = 'fadeInUpScale 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards';
        } else {
          card.style.display = 'none';
        }
      });
    });
  });
}

/**
 * 6. Accordion Acessível e Fluido para "Como Instalar"
 */
function initAccordion() {
  const accordionItems = document.querySelectorAll('.accordion-item');

  accordionItems.forEach(item => {
    const header = item.querySelector('.accordion-header');
    if (!header) return;

    header.addEventListener('click', () => {
      const isActive = item.classList.contains('active');

      // Fecha outros itens
      accordionItems.forEach(otherItem => {
        if (otherItem !== item) {
          otherItem.classList.remove('active');
          const otherHeader = otherItem.querySelector('.accordion-header');
          if (otherHeader) otherHeader.setAttribute('aria-expanded', 'false');
        }
      });

      // Alterna o item atual
      if (isActive) {
        item.classList.remove('active');
        header.setAttribute('aria-expanded', 'false');
      } else {
        item.classList.add('active');
        header.setAttribute('aria-expanded', 'true');
      }
    });
  });
}

/**
 * 7. Janela Nativa de Diálogo para Feedback (<dialog>)
 */
function initFeedbackModal() {
  const modal = document.getElementById('feedbackModal');
  const openButtons = document.querySelectorAll('.open-feedback-btn');
  const closeButton = document.getElementById('closeModalBtn');
  const feedbackForm = document.getElementById('feedbackForm');

  if (!modal) return;

  openButtons.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      modal.showModal();
    });
  });

  if (closeButton) {
    closeButton.addEventListener('click', () => {
      modal.close();
    });
  }

  // Fechar ao clicar no backdrop
  modal.addEventListener('click', (e) => {
    const dialogDimensions = modal.getBoundingClientRect();
    if (
      e.clientX < dialogDimensions.left ||
      e.clientX > dialogDimensions.right ||
      e.clientY < dialogDimensions.top ||
      e.clientY > dialogDimensions.bottom
    ) {
      modal.close();
    }
  });

  // Envio de formulário
  if (feedbackForm) {
    feedbackForm.addEventListener('submit', (e) => {
      e.preventDefault();

      const type = document.getElementById('feedbackType')?.value || 'Feedback';
      const device = document.getElementById('feedbackDevice')?.value || 'Android';
      const message = document.getElementById('feedbackMsg')?.value || '';

      modal.close();
      feedbackForm.reset();

      showToast('Mensagem enviada com sucesso. Agradecemos sua colaboração.');
      console.log(`[TupiLingo Feedback] Tipo: ${type} | Aparelho: ${device} | Mensagem: ${message}`);
    });
  }
}

/**
 * 8. Cópia do Link com Notificação Toast
 */
function initCopyLink() {
  const copyButtons = document.querySelectorAll('.copy-link-btn');

  copyButtons.forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      const urlToCopy = btn.dataset.url || 'https://github.com/felipeamlozano-ui/TupiLingo-Project/releases/download/v1.0.0-preview/app-release.apk';

      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(urlToCopy);
        } else {
          const tempInput = document.createElement('input');
          tempInput.value = urlToCopy;
          document.body.appendChild(tempInput);
          tempInput.select();
          document.execCommand('copy');
          document.body.removeChild(tempInput);
        }
        showToast('Link do APK copiado para a área de transferência.');
      } catch (err) {
        showToast('Link do APK: ' + urlToCopy);
      }
    });
  });
}

/**
 * 9. Sistema de Notificação Toast
 */
function showToast(message) {
  let toast = document.getElementById('siteToast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'siteToast';
    toast.className = 'toast';
    document.body.appendChild(toast);
  }

  toast.innerHTML = `
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--accent-green-light);"><polyline points="20 6 9 17 4 12"/></svg>
    <span>${message}</span>
  `;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3500);
}

/**
 * 10. Detecção de Dispositivo Android
 */
function detectAndroidDevice() {
  const isAndroid = /Android/i.test(navigator.userAgent);
  const devicePill = document.getElementById('deviceCompatibilityBadge');

  if (devicePill && isAndroid) {
    devicePill.innerHTML = `<strong>Dispositivo Android detectado.</strong> Pronto para download e instalação direta.`;
    devicePill.style.borderColor = 'rgba(67, 160, 71, 0.4)';
    devicePill.style.background = 'rgba(46, 125, 50, 0.15)';
    devicePill.style.color = '#81C784';
  }
}

