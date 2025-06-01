import axios from "axios";

const apiClient = axios.create({
  baseURL: "/",
  timeout: 10000,
});

const get = (url, config) => apiClient.get(url, config);
const post = (url, data, config) => apiClient.post(url, data, config);
const put = (url, data, config) => apiClient.put(url, data, config);
const del = (url, config) => apiClient.delete(url, config);
const patch = (url, data, config) => apiClient.patch(url, data, config);

const userinfo = {
  get: (config) => get("/api/v1/users/userinfo", config),
};

const accesstoken = {
  get: (config) => get("/api/v1/users/idtoken", config),
};

const api = {
  userinfo,
  accesstoken,
};

export default api;