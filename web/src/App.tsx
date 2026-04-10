import { useEffect } from "react";
import "./App.css";

const features = [
  {
    num: "01",
    title: "NOT IN YOUR TERMINAL.",
    desc: "Your terminal belongs to Claude now. Your dev server still needs to run somewhere. devtail gives it a home that isn\u2019t a tab you\u2019ll accidentally close.",
  },
  {
    num: "02",
    title: "POP OUT. LITERALLY.",
    desc: "Detach any output into a floating window. Watch your build while the agent rewrites your code. Picture-in-picture, but for terminals.",
  },
  {
    num: "03",
    title: "IT ACTUALLY KILLS THE PROCESS.",
    desc: "SIGTERM, wait 800ms, SIGKILL. Process groups, not just the shell. Your orphaned node processes finally have a parent who cares.",
  },
  {
    num: "04",
    title: "IT REMEMBERS. YOU DON\u2019T HAVE TO.",
    desc: "Restores running processes on relaunch. Reboot, grab coffee, come back to everything already running. Like you never left.",
  },
];

const steps = [
  {
    num: "01",
    title: "CONFIGURE",
    desc: "Name your process. Set the command. Pick the directory. Add log watchers if you\u2019re feeling thorough.",
  },
  {
    num: "02",
    title: "LAUNCH",
    desc: "One click. Green dot. It\u2019s running. Full terminal output with ANSI colors, streaming in real-time.",
  },
  {
    num: "03",
    title: "GIVE YOUR TERMINAL TO THE AGENT",
    desc: "Your processes live in the menu bar now. Hand the terminal over to Claude, Codex, whoever. Everything keeps running.",
  },
];

function App() {
  useEffect(() => {
    const els = document.querySelectorAll(".scroll-reveal");
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: "-40px 0px" },
    );
    for (const el of els) {
      observer.observe(el);
    }
    return () => observer.disconnect();
  }, []);

  return (
    <div className="relative min-h-screen bg-background text-foreground font-sans">
      <div className="grain" aria-hidden="true" />

      {/* ── Nav ── */}
      <nav className="flex items-center justify-between px-6 md:px-12 lg:px-16 py-6">
        <a
          href="/"
          className="text-lg font-bold tracking-[-0.02em] text-foreground no-underline"
        >
          devtail
        </a>
        <div className="flex items-center gap-6 md:gap-8">
          <a href="#download" className="cta-link text-sm font-mono">
            Download
          </a>
        </div>
      </nav>

      {/* ── Hero ── */}
      <section className="px-6 md:px-12 lg:px-16 pt-16 md:pt-24 lg:pt-36 pb-20 md:pb-28">
        <div className="max-w-[1200px] mx-auto">
          <div className="grid lg:grid-cols-12 gap-10 lg:gap-8 items-start">
            {/* Text */}
            <div className="lg:col-span-7">
              <h1 className="hero-stagger text-[2.75rem] sm:text-5xl md:text-6xl lg:text-7xl xl:text-8xl font-black leading-[1] tracking-[-0.04em]">
                <span className="block">YOUR TERMINAL</span>
                <span className="block">IS TAKEN.</span>
                <span className="block text-accent">
                  YOUR MENU BAR ISN&rsquo;T.
                </span>
              </h1>

              <p className="hero-stagger mt-6 md:mt-8 text-base md:text-lg text-muted-foreground max-w-xl leading-relaxed">
                Claude has your terminal. Codex has the other one. Your dev
                server, build watcher, and log tailer still need to run
                somewhere. devtail puts them in your menu
                bar&thinsp;&mdash;&thinsp;out of the way, always one click away.
              </p>

              <div className="hero-stagger mt-8 md:mt-10">
                <a href="./devtail.dmg" download className="cta-link text-base">
                  Download for macOS
                  <span aria-hidden="true">&nbsp;&rarr;</span>
                </a>
              </div>

              <div className="hero-stagger mt-10 md:mt-14 flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs tracking-[0.15em] text-muted-foreground uppercase">
                <span>Native SwiftUI</span>
                <span className="text-border select-none">&mdash;</span>
                <span>&lt;5 MB</span>
                <span className="text-border select-none">&mdash;</span>
                <span>macOS 14+</span>
              </div>
            </div>

            {/* Screenshot */}
            <div className="hero-stagger lg:col-span-5 lg:pt-4">
              <div className="relative">
                <div className="absolute -top-px left-0 h-[2px] w-16 bg-accent" />
                <div className="overflow-hidden border border-border">
                  <img
                    src={`${import.meta.env.BASE_URL}menubar.png`}
                    alt="devtail menu bar interface"
                    className="w-full max-w-sm lg:max-w-none transition-transform duration-500 hover:scale-[1.03]"
                  />
                </div>
              </div>
              <p className="mt-3 font-mono text-xs tracking-[0.1em] text-muted-foreground">
                &uarr; That&rsquo;s it. That&rsquo;s the whole app.
              </p>
            </div>
          </div>
        </div>
      </section>

      <hr className="border-border mx-6 md:mx-12 lg:mx-16 border-t" />

      {/* ── Features ── */}
      <section className="px-6 md:px-12 lg:px-16 py-20 md:py-28 lg:py-32">
        <div className="max-w-[1200px] mx-auto">
          <p className="scroll-reveal font-mono text-xs tracking-[0.2em] text-muted-foreground uppercase mb-12 md:mb-16">
            Features
          </p>

          <div className="grid sm:grid-cols-2 gap-4 md:gap-6">
            {features.map((f, i) => (
              <div
                key={f.num}
                className="scroll-reveal feature-card"
                style={{ "--delay": `${i * 80}ms` } as React.CSSProperties}
              >
                {/* Decorative bg number */}
                <span
                  className="absolute -top-3 -right-1 font-mono text-[5rem] md:text-[6rem] font-black leading-none select-none pointer-events-none opacity-[0.03] text-foreground"
                  aria-hidden="true"
                >
                  {f.num}
                </span>

                <div className="relative">
                  <span className="font-mono text-sm text-accent tracking-[0.1em]">
                    {f.num}
                  </span>
                  <h3 className="mt-3 text-lg md:text-xl lg:text-2xl font-bold tracking-[-0.02em] leading-tight">
                    {f.title}
                  </h3>
                  <p className="mt-3 text-sm md:text-base text-muted-foreground leading-relaxed max-w-md">
                    {f.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <hr className="border-border mx-6 md:mx-12 lg:mx-16 border-t" />

      {/* ── How It Works ── */}
      <section className="px-6 md:px-12 lg:px-16 py-20 md:py-28 lg:py-32">
        <div className="max-w-[1200px] mx-auto">
          <p className="scroll-reveal font-mono text-xs tracking-[0.2em] text-muted-foreground uppercase mb-12 md:mb-16">
            How it works
          </p>

          <div className="grid lg:grid-cols-3 gap-12 lg:gap-8">
            {steps.map((s, i) => (
              <div
                key={s.num}
                className="scroll-reveal"
                style={{ "--delay": `${i * 100}ms` } as React.CSSProperties}
              >
                <span className="block font-mono text-6xl md:text-7xl lg:text-8xl font-bold text-border leading-none tracking-[-0.04em] transition-colors duration-150 hover:text-accent cursor-default">
                  {s.num}
                </span>
                <h3 className="mt-4 md:mt-6 text-base md:text-lg font-bold tracking-[0.05em] uppercase">
                  {s.title}
                </h3>
                <p className="mt-2 md:mt-3 text-sm md:text-base text-muted-foreground leading-relaxed">
                  {s.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Final CTA (inverted) ── */}
      <section
        id="download"
        className="bg-foreground text-background px-6 md:px-12 lg:px-16 py-20 md:py-28 lg:py-40"
      >
        <div className="max-w-[1200px] mx-auto scroll-reveal">
          <h2 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl xl:text-8xl font-black tracking-[-0.04em] leading-[1]">
            FREE UP
            <br />
            <span className="text-accent">YOUR TERMINAL.</span>
          </h2>

          <div className="mt-8 md:mt-12">
            <a
              href="./devtail.dmg"
              download
              className="inline-flex items-center gap-2.5 border border-background text-background uppercase tracking-[0.1em] font-semibold py-3.5 px-6 text-sm no-underline transition-all duration-150 hover:bg-background hover:text-foreground active:translate-y-px"
            >
              Download for macOS
              <span aria-hidden="true">&rarr;</span>
            </a>
          </div>

          <p className="mt-8 font-mono text-xs tracking-[0.1em] text-muted-foreground">
            Free &amp; open source. macOS 14 Sonoma or later.
          </p>
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="px-6 md:px-12 lg:px-16 py-6 border-t border-border flex flex-col sm:flex-row justify-between items-center gap-3">
        <span className="font-mono text-xs tracking-[0.1em] text-muted-foreground">
          devtail
        </span>
        <span className="font-mono text-xs tracking-[0.1em] text-muted-foreground">
          Built with SwiftUI
        </span>
      </footer>
    </div>
  );
}

export default App;
