#ifndef T_FIELD_H
#define T_FIELD_H

#include <string>

/**
 * Class to represent a field in a thrift structure. A field has a data type,
 * a symbolic name, and a numeric identifier.
 *
 * @author Mark Slee <mcslee@facebook.com>
 */
class t_field {
 public:
  t_field(t_type* type, std::string name) :
    type_(type),
    name_(name),
    key_(0),
    xsd_optional_(false) {}

  t_field(t_type* type, std::string name, int32_t key) :
    type_(type),
    name_(name),
    key_(key),
    xsd_optional_(false) {}

  ~t_field() {}

  t_type* get_type() const {
    return type_;
  }

  const std::string& get_name() const {
    return name_;
  }

  int32_t get_key() const {
    return key_;
  }

  void set_xsd_optional(bool xsd_optional) {
    xsd_optional_ = xsd_optional;
  }

  bool get_xsd_optional() const {
    return xsd_optional_;
  }

 private:
  t_type* type_;
  std::string name_;
  int32_t key_;
  
  bool xsd_optional_;

};

#endif
