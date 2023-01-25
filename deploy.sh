#!/usr/bin/env ruby

require 'json'
require 'securerandom'
require 'optparse'

$DEV_ADMIN_PASSWORD = 'Verdi1338!'
$PARAMS_FILE = 'mainTemplateParameters.json'
$GENERATED_PARAMS_FILE = 'input-parameters.json'

def field_test(data, key, to_override)
  data['parameters'][key] = {:value => to_override} unless data['parameters'][key]
end

def args_override(data, key, to_override)
  to_override.empty? || data['parameters'][key] = {:value => to_override} # unless to_override.empty?
end

def generate_parameters_file(image_prefix, id, rg_prefix, artifact_uri, image_sku, param_file)
	data = JSON.parse(File.read(param_file))

  field_test(data, 'adminPassword', $DEV_ADMIN_PASSWORD)
  field_test(data, 'storageName', "xgsg#{rg_prefix}#{id}")
  field_test(data, 'publicIpDNS', "xgdns-#{rg_prefix}#{id}")

	# data['parameters']['vmSize']['value'] = "Standard_D2s_v3"

  args_override(data, 'imageSku', image_sku)
  args_override(data, 'devFwBlobUrlPrefix', image_prefix)
  args_override(data, '_artifactsLocation', artifact_uri)

  # p data
  # exit 0
	File.open($GENERATED_PARAMS_FILE, 'w') do |f|
  	f.write(JSON.pretty_generate(data))
	end
end

def create_resource_group(location, id, rg_prefix)
  group_name= "#{rg_prefix}-#{id}"
  print "Creating Resource Group #{group_name}\n"
  status = system("az group create --location #{location} --name #{group_name}")

  exit(1) if status == false

  group_name
end

def check_template_dir_file_exists(filename)
  unless File.exist?(filename)
    STDERR.puts "Couldn't find #{filename} in current directory (#{Dir.pwd})"
    STDERR.puts 'Are you sure you are in a directory containing the xg-azure templates?'
    exit(1)
  end
end

def run(resource_group, template)
  print "Starting deployment...\n"
  check_template_dir_file_exists(template)
  system("az group deployment create \
   --template-file #{template} \
   --parameters @#{$GENERATED_PARAMS_FILE} \
   --resource-group #{resource_group} \
   --verbose")
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: deploy.sh [(r|n)|(p|i)|l|t|d]"

  opts.on("-rRGNAME", "--resGroup RGNAME", "Existing Resource Group's Name") do |rg|
    options[:rg_name] = rg
  end
  opts.on("-nNAME", "--resGroupNamePrefix NAME", "Desired Prefix for new resource group") do |rgp|
    options[:rg_prefix] = rgp
  end
  opts.on("-iIMAGE", "--vhdPrefix IMAGE", "Dev Image Uri Prefix for VM") do |image_prefix|
    options[:image_prefix] = image_prefix
  end
  opts.on("-lLOCATION", "--location LOCATION", "Location to deploy to") do |loc|
    options[:location] = loc
  end
  opts.on("-tTEMPLOC", "--nestedTemplateLoc TEMPLOC", "Uri to your nested templates") do |tl|
    options[:artifact_uri] = tl
  end
  opts.on("-dDEPLOYTYPE", "--deploymentType DEPLOYTYPE", "HA or AA if not standalone") do |dt|
    options[:deployment_type] = dt
  end
  opts.on("-pPARAMFILE", "--paramFile PARAMFILE", "Used to overwrite default param file") do |pf|
    options[:param_file] = pf
  end
  opts.on("-sSKU", "--sku SKU", "PAYG vs BYOL SKU") do |sku|
    options[:sku] = sku
  end
end.parse!

# p options
# p ARGV

template = 'mainTemplate.json'
if options.member?(:deployment_type)
	case options[:deployment_type].downcase
	when 'ha' 
		template = 'inboundHa.json'
	when 'aa'
		template = 'AA.json'
	end
end

id = SecureRandom.hex(2)

artifact_uri = options[:artifact_uri] || ''
location = options[:location] || 'eastus'
image_prefix = options[:image_prefix] || ''
rg_prefix = options[:rg_prefix] || 'verdidev'
param_file = options[:param_file] || $PARAMS_FILE
image_sku = options[:sku] || ''

generate_parameters_file(image_prefix, id, rg_prefix, artifact_uri, image_sku, param_file)
rg_name = options.member?(:rg_name) ? options[:rg_name] : create_resource_group(location, id, rg_prefix)
run(rg_name, template)
