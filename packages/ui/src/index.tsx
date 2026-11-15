import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from "react";

export function Container({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  return <div className={wide ? "sh-container sh-container-wide" : "sh-container"}>{children}</div>;
}

export function Button({
  children,
  variant = "primary",
  size = "md",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost" | "danger";
  size?: "sm" | "md" | "lg";
}) {
  return (
    <button className={`sh-btn sh-btn-${variant} sh-btn-${size}`} {...props}>
      {children}
    </button>
  );
}

export function Card({
  children,
  className = "",
  padded = true,
}: {
  children: ReactNode;
  className?: string;
  padded?: boolean;
}) {
  return <div className={`sh-card ${padded ? "sh-card-padded" : ""} ${className}`}>{children}</div>;
}

export function Badge({
  children,
  tone = "blue",
}: {
  children: ReactNode;
  tone?: "blue" | "green" | "amber" | "red" | "gray";
}) {
  return <span className={`sh-badge sh-badge-${tone}`}>{children}</span>;
}

export function Field({
  label,
  hint,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string }) {
  return (
    <label className="sh-field">
      <span>{label}</span>
      <input {...props} />
      {hint ? <small>{hint}</small> : null}
    </label>
  );
}

export function Logo({ light = false }: { light?: boolean }) {
  return (
    <span className={`sh-logo ${light ? "sh-logo-light" : ""}`}>
      <span className="sh-logo-mark">S</span>
      <span className="sh-logo-text">
        Sharee
        <small>Đi chung, đi xa hơn</small>
      </span>
    </span>
  );
}

export function SectionTitle({
  eyebrow,
  title,
  action,
}: {
  eyebrow?: string;
  title: string;
  action?: ReactNode;
}) {
  return (
    <div className="sh-section-title">
      <div>
        {eyebrow ? <span className="sh-eyebrow">{eyebrow}</span> : null}
        <h2>{title}</h2>
      </div>
      {action}
    </div>
  );
}

export function EmptyState({ title, message }: { title: string; message: string }) {
  return (
    <div className="sh-empty">
      <div className="sh-empty-icon">✦</div>
      <strong>{title}</strong>
      <p>{message}</p>
    </div>
  );
}
