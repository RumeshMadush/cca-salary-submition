import { type RouteConfig, index, route, layout } from "@react-router/dev/routes";

export default [
  route("login", "routes/login.tsx"),
  route("signup", "routes/signup.tsx"),
  layout("components/layout/AppLayout.tsx", [
    index("routes/home.tsx"),
    route("search", "routes/search.tsx"),
    route("submit", "routes/submit.tsx"),
    route("stats", "routes/stats.tsx"),
    route("salary/:id", "routes/salary-detail.tsx"),
    route("admin", "routes/admin.tsx"),
  ]),
] satisfies RouteConfig;
