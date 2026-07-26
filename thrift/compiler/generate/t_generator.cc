/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <thrift/compiler/generate/t_generator.h>

#include <algorithm>
#include <sstream>
#include <stdexcept>
#include <utility>

#include <fmt/core.h>

namespace apache::thrift::compiler {

namespace {
/**
 * Add consistent indentation and line breaks to the generator documentation
 * passed to `THRIFT_REGISTER_GENERATOR`.
 */
std::string normalize_documentation(std::string_view doc) {
  static constexpr auto kIndent = "    ";
  std::ostringstream out;
  while (!doc.empty()) {
    std::string_view line = doc.substr(0, doc.find_first_of('\n'));
    doc.remove_prefix(std::min(doc.size(), line.size() + 1));
    if (!line.empty()) {
      out << kIndent << line;
    }
    out << '\n';
  }
  return out.str();
}

void append_indented(std::string& output, std::string_view text) {
  while (!text.empty()) {
    const auto line_end = text.find('\n');
    const auto line = text.substr(0, line_end);
    output.append("  ");
    output.append(line);
    output.push_back('\n');
    if (line_end == std::string_view::npos) {
      break;
    }
    text.remove_prefix(line_end + 1);
  }
}
} // namespace

std::string make_generator_documentation(
    std::string_view introduction,
    std::string_view usage,
    std::span<const generator_option_spec> options) {
  std::string result{introduction};
  result.append("\n\nUsage: ");
  result.append(usage);
  result.append(
      "\nOptions are comma-separated and disabled by default unless stated."
      "\n\n");
  for (const auto& option : options) {
    result.append(option.usage);
    result.push_back('\n');
    append_indented(result, option.description);
#ifndef THRIFT_OSS
    if (!option.internal_documentation.empty()) {
      append_indented(
          result,
          fmt::format(
              "Internal documentation: {}", option.internal_documentation));
    }
#endif
  }
  return result;
}

void validate_generator_options(
    std::string_view language,
    const std::map<std::string, std::string>& options,
    std::span<const generator_option_spec> supported_options) {
  for (const auto& [name, value] : options) {
    const auto option = std::find_if(
        supported_options.begin(),
        supported_options.end(),
        [&](const auto& candidate) { return candidate.name == name; });
    if (option == supported_options.end()) {
      throw std::runtime_error(
          fmt::format(
              "Unknown {} generator option `{}`; run `thrift1 --help` for the "
              "supported options",
              language,
              name));
    }
    switch (option->value_policy) {
      case generator_option_value_policy::flag:
        if (!value.empty()) {
          throw std::runtime_error(
              fmt::format(
                  "{} generator option `{}` does not take a value",
                  language,
                  name));
        }
        break;
      case generator_option_value_policy::required:
        if (value.empty()) {
          throw std::runtime_error(
              fmt::format(
                  "{} generator option `{}` requires a value", language, name));
        }
        break;
      case generator_option_value_policy::optional:
        break;
    }
  }
}

void t_generator::process_options(
    const std::map<std::string, std::string>& options,
    std::string out_path,
    bool add_gen_dir) {
  std::filesystem::path path = {out_path};
  if (!out_path.empty() && out_path.back() != '/' && out_path.back() != '\\') {
    path += std::filesystem::path::preferred_separator;
  }
  out_path_ = path.make_preferred().string();
  add_gen_dir_ = add_gen_dir;
  process_options(options);
}

generator_factory::generator_factory(
    std::string name, std::string long_name, std::string_view documentation)
    : name_(std::move(name)),
      long_name_(std::move(long_name)),
      documentation_(normalize_documentation(documentation)) {
  generator_registry::register_generator(name_, this);
}

void generator_registry::register_generator(
    const std::string& name, generator_factory* factory) {
  if (!get_generators().insert({name, factory}).second) {
    throw std::logic_error(fmt::format("duplicate generator \"{}\"", name));
  }
}

std::unique_ptr<t_generator> generator_registry::make_generator(
    const std::string& name,
    t_program& p,
    t_program_bundle& pb,
    diagnostics_engine& diags) {
  generator_map& map = get_generators();
  const auto& aliases = get_generator_aliases();
  const auto alias = aliases.find(name);
  const std::string& registered_name =
      alias == aliases.end() ? name : alias->second;
  auto iter = map.find(registered_name);
  return iter != map.end() ? iter->second->make_generator(p, pb, diags)
                           : nullptr;
}

generator_registry::generator_map& generator_registry::get_generators() {
  // http://www.parashift.com/c++-faq-lite/ctors.html#faq-10.12
  static generator_map* map = new generator_map();
  return *map;
}

const generator_registry::generator_alias_map&
generator_registry::get_generator_aliases() {
  static const generator_alias_map* aliases = new generator_alias_map{
      {"cpp", "mstch_cpp2"},
      {"cpp2", "mstch_cpp2"},
      {"py3", "mstch_py3"},
      {"python", "mstch_python"},
  };
  return *aliases;
}

} // namespace apache::thrift::compiler
