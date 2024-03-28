const validator = require("email-validator");
const slugify = require("slugify");

exports.emailValidator = validator.validate;

exports.slugify = slugify;

exports.join = (s, separator) => s.join(separator);
