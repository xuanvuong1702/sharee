// ../../packages/ui/src/index.tsx
import { jsx, jsxs } from "react/jsx-runtime";
function Container({ children, wide = false }) {
  return /* @__PURE__ */ jsx("div", { className: wide ? "sh-container sh-container-wide" : "sh-container", children });
}
function Button({
  children,
  variant = "primary",
  size = "md",
  ...props
}) {
  return /* @__PURE__ */ jsx("button", { className: `sh-btn sh-btn-${variant} sh-btn-${size}`, ...props, children });
}
function Card({
  children,
  className = "",
  padded = true
}) {
  return /* @__PURE__ */ jsx("div", { className: `sh-card ${padded ? "sh-card-padded" : ""} ${className}`, children });
}
function Badge({
  children,
  tone = "blue"
}) {
  return /* @__PURE__ */ jsx("span", { className: `sh-badge sh-badge-${tone}`, children });
}
function Field({
  label,
  hint,
  ...props
}) {
  return /* @__PURE__ */ jsxs("label", { className: "sh-field", children: [
    /* @__PURE__ */ jsx("span", { children: label }),
    /* @__PURE__ */ jsx("input", { ...props }),
    hint ? /* @__PURE__ */ jsx("small", { children: hint }) : null
  ] });
}
function Logo({ light = false }) {
  return /* @__PURE__ */ jsxs("span", { className: `sh-logo ${light ? "sh-logo-light" : ""}`, children: [
    /* @__PURE__ */ jsx("span", { className: "sh-logo-mark", children: "S" }),
    /* @__PURE__ */ jsxs("span", { className: "sh-logo-text", children: [
      "Sharee",
      /* @__PURE__ */ jsx("small", { children: "\u0110i chung, \u0111i xa h\u01A1n" })
    ] })
  ] });
}
function SectionTitle({
  eyebrow,
  title,
  action
}) {
  return /* @__PURE__ */ jsxs("div", { className: "sh-section-title", children: [
    /* @__PURE__ */ jsxs("div", { children: [
      eyebrow ? /* @__PURE__ */ jsx("span", { className: "sh-eyebrow", children: eyebrow }) : null,
      /* @__PURE__ */ jsx("h2", { children: title })
    ] }),
    action
  ] });
}
function EmptyState({ title, message }) {
  return /* @__PURE__ */ jsxs("div", { className: "sh-empty", children: [
    /* @__PURE__ */ jsx("div", { className: "sh-empty-icon", children: "\u2726" }),
    /* @__PURE__ */ jsx("strong", { children: title }),
    /* @__PURE__ */ jsx("p", { children: message })
  ] });
}
export {
  Badge,
  Button,
  Card,
  Container,
  EmptyState,
  Field,
  Logo,
  SectionTitle
};
