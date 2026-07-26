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

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include <fmt/format.h>

#include <thrift/compiler/ast/t_enum.h>
#include <thrift/compiler/ast/t_include.h>
#include <thrift/compiler/ast/t_list.h>
#include <thrift/compiler/ast/t_map.h>
#include <thrift/compiler/ast/t_primitive_type.h>
#include <thrift/compiler/ast/t_program.h>
#include <thrift/compiler/ast/t_set.h>
#include <thrift/compiler/ast/t_struct.h>
#include <thrift/compiler/ast/t_structured.h>
#include <thrift/compiler/ast/t_typedef.h>
#include <thrift/compiler/ast/t_union.h>
#include <thrift/compiler/ast/uri.h>
#include <thrift/compiler/generate/cpp/name_resolver.h>
#include <thrift/compiler/generate/cpp/reference_type.h>
#include <thrift/compiler/generate/t_generator.h>

namespace apache::thrift::compiler {
namespace {

constexpr std::string_view kPatchUriAnnotation = "thrift.patch.uri";

std::string primitive_name(t_primitive_type::type type) {
  switch (type) {
    case t_primitive_type::type::t_void:
      return "void";
    case t_primitive_type::type::t_string:
      return "string";
    case t_primitive_type::type::t_bool:
      return "bool";
    case t_primitive_type::type::t_byte:
      return "byte";
    case t_primitive_type::type::t_i16:
      return "i16";
    case t_primitive_type::type::t_i32:
      return "i32";
    case t_primitive_type::type::t_i64:
      return "i64";
    case t_primitive_type::type::t_double:
      return "double";
    case t_primitive_type::type::t_float:
      return "float";
    case t_primitive_type::type::t_binary:
      return "binary";
  }
  throw std::runtime_error("unknown Thrift primitive type");
}

std::string primitive_patch_name(t_primitive_type::type type) {
  switch (type) {
    case t_primitive_type::type::t_bool:
      return "patch.BoolPatch";
    case t_primitive_type::type::t_byte:
      return "patch.BytePatch";
    case t_primitive_type::type::t_i16:
      return "patch.I16Patch";
    case t_primitive_type::type::t_i32:
      return "patch.I32Patch";
    case t_primitive_type::type::t_i64:
      return "patch.I64Patch";
    case t_primitive_type::type::t_float:
      return "patch.FloatPatch";
    case t_primitive_type::type::t_double:
      return "patch.DoublePatch";
    case t_primitive_type::type::t_string:
      return "patch.StringPatch";
    case t_primitive_type::type::t_binary:
      return "patch.BinaryPatch";
    case t_primitive_type::type::t_void:
      break;
  }
  throw std::runtime_error("void has no patch representation");
}

std::string normalized_field_suffix(t_field_id id, size_t depth) {
  const auto normalized_id = id < 0 ? -id : id;
  return fmt::format(
      "Field{}Patch{}", normalized_id, depth == 0 ? "" : std::to_string(depth));
}

class t_cpp2_patch_generator final : public t_generator {
 public:
  using t_generator::t_generator;

  void process_options(
      const std::map<std::string, std::string>& options) override {
    out_dir_base_ = "gen-patch";
    const auto source = options.find("source_include");
    if (source == options.end() || source->second.empty()) {
      throw std::invalid_argument(
          "cpp2_patch requires source_include=<include/path.thrift>");
    }
    source_include_ = source->second;
  }

  void generate_program() override;

 private:
  struct generated_definition {
    std::string text;
  };

  bool should_generate(const t_structured& type) const;
  bool is_assign_only(const t_named& node) const {
    return node.has_structured_annotation(kAssignOnlyPatchUri);
  }
  bool is_struct_type(const t_type& type) const {
    return type.get_true_type()->is<t_struct>();
  }
  bool is_patchable_field(const t_field& field) const {
    const auto ref_type = gen::cpp::find_ref_type(field);
    return ref_type != gen::cpp::reference_type::shared_const &&
        ref_type != gen::cpp::reference_type::shared_mutable;
  }

  std::string include_alias(const t_program& program) const;
  std::string type_name(const t_type& type) const;
  std::string patch_type_name(
      const t_type& type,
      const t_structured& owner,
      t_field_id field_id,
      size_t depth,
      bool assign_only);
  std::string patch_override(const t_type& type) const;
  std::string uri_annotation(std::string_view uri) const;
  std::string adapter_annotation(
      std::string_view name, std::string_view adapter) const;
  std::string field(
      t_field_id id,
      std::string_view type,
      std::string_view name,
      bool optional = false,
      bool box = false,
      std::string_view annotation = {}) const;
  void generate_container_patch(
      const t_type& type,
      const t_structured& owner,
      t_field_id field_id,
      size_t depth,
      bool assign_only,
      std::string name);
  void generate_patch(const t_structured& type);
  void visit_patch_dependency(
      const t_type& type,
      std::vector<const t_structured*>& ordered,
      std::unordered_map<const t_structured*, int>& state) const;
  void generate_traits_header(
      const std::filesystem::path& output,
      const std::vector<const t_structured*>& ordered) const;
  void generate_instantiations_source(
      const std::filesystem::path& output,
      const std::vector<const t_structured*>& ordered) const;

  std::string source_include_;
  std::map<const t_program*, std::string> include_aliases_;
  std::vector<generated_definition> definitions_;
};

bool t_cpp2_patch_generator::should_generate(const t_structured& type) const {
  const auto& definitions = program_->structured_definitions();
  const bool has_selection = std::any_of(
      definitions.begin(),
      definitions.end(),
      [](const t_structured* candidate) {
        return candidate->has_structured_annotation(kGeneratePatchNewUri);
      });
  return !has_selection || type.has_structured_annotation(kGeneratePatchNewUri);
}

std::string t_cpp2_patch_generator::include_alias(
    const t_program& program) const {
  if (&program == program_) {
    return "patch_source";
  }
  const auto it = include_aliases_.find(&program);
  if (it != include_aliases_.end()) {
    return it->second;
  }
  throw std::runtime_error(
      fmt::format(
          "patch generation requires a direct include for type program `{}`",
          program.name()));
}

std::string t_cpp2_patch_generator::type_name(const t_type& type) const {
  if (const auto* primitive = type.try_as<t_primitive_type>()) {
    return primitive_name(primitive->primitive_type());
  }
  if (const auto* list = type.try_as<t_list>()) {
    return fmt::format("list<{}>", type_name(list->elem_type().deref()));
  }
  if (const auto* set = type.try_as<t_set>()) {
    return fmt::format("set<{}>", type_name(set->elem_type().deref()));
  }
  if (const auto* map = type.try_as<t_map>()) {
    return fmt::format(
        "map<{}, {}>",
        type_name(map->key_type().deref()),
        type_name(map->val_type().deref()));
  }
  if (type.program() == nullptr) {
    throw std::runtime_error(
        fmt::format("type `{}` has no owning program", type.name()));
  }
  return fmt::format("{}.{}", include_alias(*type.program()), type.name());
}

std::string t_cpp2_patch_generator::patch_override(const t_type& type) const {
  const auto* uri = t_typedef::get_first_unstructured_annotation_or_null(
      &type, {kPatchUriAnnotation});
  if (uri == nullptr) {
    return {};
  }
  if (*uri == "facebook.com/thrift/op/AnyPatch") {
    return "any_patch.AnyPatch";
  }
  throw std::runtime_error(
      fmt::format("unsupported custom patch URI `{}`", *uri));
}

std::string t_cpp2_patch_generator::patch_type_name(
    const t_type& type,
    const t_structured& owner,
    t_field_id field_id,
    size_t depth,
    bool assign_only) {
  if (const auto override = patch_override(type); !override.empty()) {
    return override;
  }
  const t_type& true_type = *type.get_true_type();
  if (const auto* primitive = true_type.try_as<t_primitive_type>()) {
    return primitive_patch_name(primitive->primitive_type());
  }
  if (const auto* structured = true_type.try_as<t_structured>()) {
    if (structured->program() == program_) {
      return structured->name() + "Patch";
    }
    throw std::runtime_error(
        fmt::format(
            "patch dependency for included structured type `{}` is not available",
            structured->get_scoped_name()));
  }

  const auto name = owner.name() + normalized_field_suffix(field_id, depth);
  generate_container_patch(type, owner, field_id, depth, assign_only, name);
  return name;
}

std::string t_cpp2_patch_generator::uri_annotation(std::string_view uri) const {
  if (uri.empty()) {
    return {};
  }
  return fmt::format("@thrift.Uri{{value = \"{}\"}}\n", uri);
}

std::string t_cpp2_patch_generator::adapter_annotation(
    std::string_view name, std::string_view adapter) const {
  const auto ns = cpp_name_resolver::gen_namespace(*program_);
  return fmt::format(
      "@cpp.Adapter{{\n"
      "  underlyingName = \"{}Struct\",\n"
      "  name = \"::apache::thrift::op::detail::{}<{}::{}Struct>\",\n"
      "  extraNamespace = \"\",\n"
      "}}\n",
      name,
      adapter,
      ns,
      name);
}

std::string t_cpp2_patch_generator::field(
    t_field_id id,
    std::string_view type,
    std::string_view name,
    bool optional,
    bool box,
    std::string_view annotation) const {
  std::string result;
  if (!annotation.empty()) {
    result += fmt::format("  {}\n", annotation);
  }
  if (box) {
    result += "  @thrift.Box\n";
  }
  result += fmt::format(
      "  {}: {}{} {};\n", id, optional ? "optional " : "", type, name);
  return result;
}

void t_cpp2_patch_generator::generate_container_patch(
    const t_type& type,
    const t_structured& owner,
    t_field_id field_id,
    size_t depth,
    bool assign_only,
    std::string name) {
  const t_type& true_type = *type.get_true_type();
  std::string body;
  body += field(1, type_name(type), "assign", true, is_struct_type(type));
  body += field(2, "bool", "clear");

  std::string adapter = "AssignPatchAdapter";
  if (!assign_only) {
    if (true_type.is<t_list>()) {
      body += field(8, type_name(type), "prepend");
      body += field(9, type_name(type), "append");
      adapter = "ListPatchAdapter";
    } else if (true_type.is<t_set>()) {
      body += field(7, type_name(type), "remove");
      body += field(8, type_name(type), "add");
      adapter = "SetPatchAdapter";
    } else if (const auto* map = true_type.try_as<t_map>()) {
      const auto value_patch = patch_type_name(
          map->val_type().deref(), owner, field_id, depth + 1, false);
      const auto patch_map = fmt::format(
          "map<{}, {}>", type_name(map->key_type().deref()), value_patch);
      constexpr std::string_view kPatchMapType =
          "@cpp.Type{template = \"folly::F14NodeMap\"}";
      body += field(3, patch_map, "patchPrior", false, false, kPatchMapType);
      body += field(5, type_name(type), "add");
      body += field(6, patch_map, "patch", false, false, kPatchMapType);
      body += field(
          7,
          fmt::format("set<{}>", type_name(map->key_type().deref())),
          "remove",
          false,
          false,
          "@cpp.Type{template = \"std::unordered_set\"}");
      body += field(9, type_name(type), "put");
      adapter = "MapPatchAdapter";
    }
  }

  const auto uri = owner.uri().empty()
      ? std::string{}
      : owner.uri() + normalized_field_suffix(field_id, depth);
  definitions_.push_back({fmt::format(
      "\n{}{}struct {} {{\n{}}}\n",
      uri_annotation(uri),
      adapter_annotation(name, adapter),
      name,
      body)});
}

void t_cpp2_patch_generator::generate_patch(const t_structured& type) {
  std::vector<const t_field*> fields(
      type.fields_id_order().begin(), type.fields_id_order().end());

  std::string field_patch_body;
  for (const t_field* current : fields) {
    if (!current->type().resolved() || !is_patchable_field(*current)) {
      continue;
    }
    const bool assign_only =
        current->has_structured_annotation(kAssignOnlyPatchUri);
    const auto patch_type = patch_type_name(
        current->type().deref(), type, current->id(), 0, assign_only);
    field_patch_body += field(current->id(), patch_type, current->name());
  }

  const auto field_patch_name = type.name() + "FieldPatch";
  definitions_.push_back({fmt::format(
      "\n{}{}struct {} {{\n{}}}\n",
      uri_annotation(type.uri().empty() ? "" : type.uri() + "FieldPatch"),
      adapter_annotation(field_patch_name, "FieldPatchAdapter"),
      field_patch_name,
      field_patch_body)});

  std::string ensure_body;
  for (const t_field* current : fields) {
    if (!current->type().resolved()) {
      continue;
    }
    ensure_body += field(
        current->id(),
        type_name(current->type().deref()),
        current->name(),
        true,
        is_struct_type(current->type().deref()));
  }
  const auto ensure_name = type.name() + "EnsureStruct";
  definitions_.push_back({fmt::format(
      "\n{}struct {} {{\n{}}}\n",
      uri_annotation(type.uri().empty() ? "" : type.uri() + "EnsureStruct"),
      ensure_name,
      ensure_body)});

  const auto patch_name = type.name() + "Patch";
  std::string patch_body;
  patch_body += field(1, type_name(type), "assign", true, is_struct_type(type));
  patch_body += field(2, "bool", "clear");
  std::string adapter = "AssignPatchAdapter";
  if (!is_assign_only(type)) {
    patch_body += field(3, field_patch_name, "patchPrior");
    if (type.is<t_union>()) {
      patch_body += field(4, type_name(type), "ensure");
      adapter = "UnionPatchAdapter";
    } else {
      patch_body += field(5, ensure_name, "ensure");
      patch_body += field(7, "patch.FieldIdList", "remove");
      adapter = "StructPatchAdapter";
    }
    patch_body += field(6, field_patch_name, "patch");
  }
  definitions_.push_back({fmt::format(
      "\n{}{}struct {} {{\n{}}}\n",
      uri_annotation(type.uri().empty() ? "" : type.uri() + "Patch"),
      adapter_annotation(patch_name, adapter),
      patch_name,
      patch_body)});

  const auto safe_patch_name = type.name() + "SafePatch";
  std::string safe_patch_body;
  safe_patch_body += field(1, "i32", "version");
  safe_patch_body += field(
      2,
      "binary",
      "data",
      false,
      false,
      "@cpp.Type{name = \"std::unique_ptr<folly::IOBuf>\"}");
  definitions_.push_back({fmt::format(
      "\n{}struct {} {{\n{}}}\n",
      uri_annotation(type.uri().empty() ? "" : type.uri() + "SafePatch"),
      safe_patch_name,
      safe_patch_body)});
}

void t_cpp2_patch_generator::visit_patch_dependency(
    const t_type& type,
    std::vector<const t_structured*>& ordered,
    std::unordered_map<const t_structured*, int>& state) const {
  const t_type& true_type = *type.get_true_type();
  if (const auto* structured = true_type.try_as<t_structured>()) {
    if (structured->program() != program_ || !should_generate(*structured)) {
      return;
    }
    int& current_state = state[structured];
    if (current_state == 2) {
      return;
    }
    if (current_state == 1) {
      // Recursive types are legal. Their patch declarations are handled by
      // cpp2's forward-declaration output, so terminate this dependency edge.
      return;
    }
    current_state = 1;
    for (const t_field& field : structured->fields()) {
      if (field.type().resolved()) {
        visit_patch_dependency(field.type().deref(), ordered, state);
      }
    }
    current_state = 2;
    ordered.push_back(structured);
    return;
  }
  if (const auto* list = true_type.try_as<t_list>()) {
    visit_patch_dependency(list->elem_type().deref(), ordered, state);
  } else if (const auto* set = true_type.try_as<t_set>()) {
    visit_patch_dependency(set->elem_type().deref(), ordered, state);
  } else if (const auto* map = true_type.try_as<t_map>()) {
    visit_patch_dependency(map->key_type().deref(), ordered, state);
    visit_patch_dependency(map->val_type().deref(), ordered, state);
  }
}

void t_cpp2_patch_generator::generate_traits_header(
    const std::filesystem::path& output,
    const std::vector<const t_structured*>& ordered) const {
  std::ofstream out(output);
  if (!out) {
    throw std::runtime_error(
        fmt::format("failed to open `{}`", output.string()));
  }

  const auto ns = cpp_name_resolver::gen_namespace(*program_);
  const auto source_fwd_include =
      std::filesystem::path(source_include_).parent_path() / "gen-cpp2" /
      (program_->name() + "_types_fwd.h");

  out << "// @generated by thrift --gen cpp2_patch\n\n";
  out << "#pragma once\n\n";
  out << "#include <thrift/lib/cpp2/type/Tag.h>\n";
  out << "#include \"" << source_fwd_include.generic_string() << "\"\n\n";

  out << "namespace " << ns.substr(2) << " {\n";
  for (const t_structured* type : ordered) {
    out << "class " << type->name() << "PatchStruct;\n";
    out << "class " << type->name() << "SafePatch;\n";
  }
  out << "} // namespace " << ns.substr(2) << "\n\n";

  out << "namespace apache::thrift::op::detail {\n";
  out << "template <class T> struct PatchType;\n";
  out << "template <class T> struct SafePatchType;\n";
  out << "template <class T> struct SafePatchValueType;\n";
  out << "template <class T> class StructPatch;\n";
  out << "template <class T> class UnionPatch;\n\n";
  for (const t_structured* type : ordered) {
    const auto tag = type->is<t_union>() ? "union_t" : "struct_t";
    const auto value = fmt::format("{}::{}", ns, type->name());
    const auto patch_struct =
        fmt::format("{}::{}PatchStruct", ns, type->name());
    const auto safe_patch = fmt::format("{}::{}SafePatch", ns, type->name());
    const auto patch_class = type->is<t_union>() ? "UnionPatch" : "StructPatch";

    out << "template <>\n";
    out << "struct PatchType<::apache::thrift::type::" << tag << "<" << value
        << ">> {\n";
    out << "  using type = " << patch_class << "<" << patch_struct << ">;\n";
    out << "};\n";
    out << "template <>\n";
    out << "struct SafePatchType<::apache::thrift::type::" << tag << "<"
        << value << ">> {\n";
    out << "  using type = " << safe_patch << ";\n";
    out << "};\n";
    out << "template <>\n";
    out << "struct SafePatchValueType<" << safe_patch << "> {\n";
    out << "  using type = " << value << ";\n";
    out << "};\n\n";
  }
  out << "} // namespace apache::thrift::op::detail\n";
}

void t_cpp2_patch_generator::generate_instantiations_source(
    const std::filesystem::path& output,
    const std::vector<const t_structured*>& ordered) const {
  std::ofstream out(output);
  if (!out) {
    throw std::runtime_error(
        fmt::format("failed to open `{}`", output.string()));
  }

  const auto ns = cpp_name_resolver::gen_namespace(*program_);
  const auto patch_types_include =
      std::filesystem::path(source_include_).parent_path() / "gen-cpp2" /
      ("gen_patch_" + program_->name() + "_types.h");

  out << "// @generated by thrift --gen cpp2_patch\n\n";
  out << "#include \"" << patch_types_include.generic_string() << "\"\n";
  out << "#include <thrift/lib/cpp2/op/detail/StructPatchImpl.h>\n\n";
  out << "namespace apache::thrift::op::detail {\n";
  for (const t_structured* type : ordered) {
    const auto value = fmt::format("{}::{}", ns, type->name());
    const auto patch_struct =
        fmt::format("{}::{}PatchStruct", ns, type->name());
    const auto field_patch = fmt::format("{}::{}FieldPatch", ns, type->name());
    const auto patch_class = type->is<t_union>() ? "UnionPatch" : "StructPatch";
    const auto derived = fmt::format("{}<{}>", patch_class, patch_struct);
    const auto base =
        fmt::format("BaseEnsurePatch<{}, {}>", patch_struct, derived);

    out << "template void " << base << "::apply(" << value << "&) const;\n";
    out << "template void " << derived << "::merge(const " << derived
        << "&);\n";
    out << "template void " << derived << "::merge(" << derived << "&&);\n";
    for (const t_field& current : type->fields()) {
      if (!current.type().resolved() || !is_patchable_field(current)) {
        continue;
      }
      out << "template auto " << base
          << "::patchImpl<::apache::thrift::type::field_id<" << current.id()
          << ">>() -> " << field_patch << "&;\n";
    }
    out << "\n";
  }
  out << "} // namespace apache::thrift::op::detail\n";
}

void t_cpp2_patch_generator::generate_program() {
  std::filesystem::create_directories(get_out_path());
  const auto thrift_output =
      get_out_path() / ("gen_patch_" + program_->name() + ".thrift");
  const auto traits_output =
      get_out_path() / ("gen_patch_" + program_->name() + ".h");
  const auto instantiations_output =
      get_out_path() / ("gen_patch_" + program_->name() + ".cpp");
  std::ofstream out(thrift_output);
  if (!out) {
    throw std::runtime_error(
        fmt::format("failed to open `{}`", thrift_output.string()));
  }
  record_genfile(thrift_output);
  record_genfile(traits_output);
  record_genfile(instantiations_output);

  out << "// @generated by thrift --gen cpp2_patch\n\n";
  out << "include \"" << source_include_ << "\" as patch_source\n";
  out << "include \"thrift/annotation/cpp.thrift\"\n";
  out << "include \"thrift/annotation/thrift.thrift\"\n";
  out << "include \"thrift/lib/thrift/any_patch.thrift\"\n";
  out << "include \"thrift/lib/thrift/patch.thrift\"\n";

  for (const t_include* include : program_->includes()) {
    const auto raw_path = include->raw_path();
    if (raw_path == "thrift/lib/thrift/patch.thrift" ||
        raw_path == "thrift/annotation/cpp.thrift" ||
        raw_path == "thrift/annotation/thrift.thrift" ||
        raw_path == "thrift/lib/thrift/any_patch.thrift") {
      include_aliases_[include->get_program()] = std::string(
          include->alias().value_or(include->get_program()->name()));
      continue;
    }
    const auto alias =
        std::string(include->alias().value_or(include->get_program()->name()));
    include_aliases_[include->get_program()] = alias;
    out << "include \"" << raw_path << "\" as " << alias << "\n";
  }

  const auto traits_include =
      std::filesystem::path(source_include_).parent_path() / "gen-patch" /
      traits_output.filename();
  out << "\ncpp_include \"thrift/lib/cpp2/op/detail/Patch.h\"\n";
  out << "cpp_include \"" << traits_include.generic_string() << "\"\n\n";
  out << "@thrift.TerseWrite\n";
  if (program_->package().is_explicit()) {
    out << "package \"" << program_->package().name() << "\"\n";
  }
  for (const t_namespace* ns : program_->all_namespace_nodes()) {
    out << "namespace " << ns->language() << " " << ns->ns() << "\n";
  }

  std::vector<const t_structured*> ordered;
  std::unordered_map<const t_structured*, int> state;
  for (const t_structured* type : program_->structured_definitions()) {
    if (should_generate(*type)) {
      visit_patch_dependency(*type, ordered, state);
    }
  }
  for (const t_structured* type : ordered) {
    generate_patch(*type);
  }
  generate_traits_header(traits_output, ordered);
  generate_instantiations_source(instantiations_output, ordered);
  for (const auto& definition : definitions_) {
    out << definition.text;
  }
}

THRIFT_REGISTER_GENERATOR(
    cpp2_patch,
    "C++ patch companion IDL",
    "Generates gen_patch_<program>.thrift for the cpp2 patch library rule.");

} // namespace
} // namespace apache::thrift::compiler
