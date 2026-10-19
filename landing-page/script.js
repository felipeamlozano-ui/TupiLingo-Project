/**
 * TupiLingo • Landing Page Interactions
 * Mobile-First, Accessible, Native Dialogs & Showcase Switcher
 */

document.addEventListener('DOMContentLoaded', () => {
  initShowcaseTabs();
  initAccordion();
  initFeedbackModal();
  initCopyLink();
  detectAndroidDevice();
});

/**
 * 1. Showcase Filter & Screen Switcher
 */
function initShowcaseTabs() {
  const tabButtons = document.querySelectorAll('.tab-btn');
  const showcaseCards = document.querySelectorAll('.showcase-card');

  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetCategory = btn.dataset.category;

      // Update active state on buttons
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      // Filter cards
      showcaseCards.forEach(card => {
        if (targetCategory === 'all' || card.dataset.category === targetCategory) {
          card.style.display = 'flex';
          card.style.animation = 'fadeInUp 0.4s ease forwards';
        } else {
          card.style.display = 'none';
        }
      });
    });
  });
}

/**
 * 2. Accessible Accordion for "Como Instalar"
 */
function initAccordion() {
  const accordionItems = document.querySelectorAll('.accordion-item');

  accordionItems.forEach((item, index) => {
    const header = item.querySelector('.accordion-header');
    
    header.addEventListener('click', () => {
      const isActive = item.classList.contains('active');

      // Close all other items (single expand pattern)
      accordionItems.forEach(otherItem => {
        if (otherItem !== item) {
          otherItem.classList.remove('active');
          otherItem.querySelector('.accordion-header').setAttribute('aria-expanded', 'false');
        }
      });

      // Toggle current item
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
 * 3. Native Feedback Dialog (<dialog>)
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

  // Light dismiss: Close on clicking backdrop
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

  // Handle form submission
  if (feedbackForm) {
    feedbackForm.addEventListener('submit', (e) => {
      e.preventDefault();

      const type = document.getElementById('feedbackType')?.value || 'Feedback';
      const device = document.getElementById('feedbackDevice')?.value || 'Android';
      const message = document.getElementById('feedbackMsg')?.value || '';

      // Close modal
      modal.close();
      feedbackForm.reset();

      // Show toast
      showToast('Mensagem enviada com sucesso. Agradecemos sua colaboração.');

      // Feedback log
      console.log(`[TupiLingo Feedback] Tipo: ${type} | Aparelho: ${device} | Mensagem: ${message}`);
    });
  }
}

/**
 * 4. Copy APK Link with Toast
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
          // Fallback
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
 * 5. Toast Notification System
 */
function showToast(message) {
  let toast = document.getElementById('siteToast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'siteToast';
    toast.className = 'toast';
    document.body.appendChild(toast);
  }

  toast.textContent = message;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3500);
}

/**
 * 6. Detect Android Device & Customize Greeting
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
