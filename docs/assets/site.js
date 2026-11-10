(function () {
  var nav = document.getElementById('nav');
  var onScroll = function () { nav.classList.toggle('scrolled', window.scrollY > 12); };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  if (!window.gsap) { return; }
  gsap.registerPlugin(ScrollTrigger);

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hint = document.getElementById('hint');
  var hintEnd = hint ? (hint.getAttribute('data-hint-end') || '') : '';
  var hintReduced = hint ? (hint.getAttribute('data-hint-reduced') || hintEnd) : '';

  // Lenis smooth scroll wired to ScrollTrigger
  if (window.Lenis && !reduce) {
    var lenis = new Lenis({ duration: 1.05, smoothWheel: true });
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add(function (t) { lenis.raf(t * 1000); });
    gsap.ticker.lagSmoothing(0);
  }

  var mm = gsap.matchMedia();

  // Scroll-driven hero: the active Dock + menu bar + cursor follow to the other screen
  mm.add('(prefers-reduced-motion: no-preference)', function () {
    var tl = gsap.timeline({
      scrollTrigger: { trigger: '#heroPin', start: 'top top', end: '+=120%', scrub: 0.6, pin: true, anticipatePin: 1 }
    });
    tl.to(['#dock', '#menubar', '#hint'], { left: '76.5%', ease: 'power1.inOut' }, 0)
      .to('#cursor', { left: '79%', bottom: '46%', ease: 'power1.inOut' }, 0)
      .to('#hint', { opacity: 0, duration: 0.18 }, 0)
      .add(function () { if (hint) hint.textContent = hintEnd; })
      .to('#hint', { opacity: 0.9, duration: 0.2 }, 0.55);
  });

  // Reduced motion: place the active cluster on the right, no pin
  mm.add('(prefers-reduced-motion: reduce)', function () {
    gsap.set(['#dock', '#menubar', '#hint'], { left: '76.5%' });
    gsap.set('#cursor', { left: '79%' });
    if (hint) hint.textContent = hintReduced;
  });

  // Block entrance animations (scroll-triggered, once)
  gsap.utils.toArray('[data-rise]').forEach(function (el, i) {
    gsap.from(el, {
      y: 34, opacity: 0, duration: 0.7, ease: 'back.out(1.5)',
      scrollTrigger: { trigger: el, start: 'top 86%', once: true },
      delay: (i % (window.innerWidth < 760 ? 1 : 2)) * 0.06
    });
  });
  gsap.utils.toArray('.sec-head').forEach(function (el) {
    gsap.from(el.children, {
      y: 22, opacity: 0, duration: 0.6, stagger: 0.08, ease: 'power2.out',
      scrollTrigger: { trigger: el, start: 'top 88%', once: true }
    });
  });
})();
